//
//  AudioBlockPump.swift
//  ttaccessible
//
//  Drains per-user audio blocks from the TeamTalk SDK on a dedicated
//  high-priority timer, decoupled from the 20 ms message loop.
//
//  WHY: audio blocks used to be acquired inside the message-loop drain
//  (CLIENTEVENT_USER_AUDIOBLOCK → TT_AcquireUserAudioBlock) on the
//  controller's serial queue. That queue also runs the channel-tree
//  publish, history appends and VU/state updates — all of which grow
//  with the number of users in the channel. In a crowded channel a
//  single slow tick (longer than the ~25 ms per-user jitter buffer)
//  starves EVERY mix source at once, so everyone's audio went choppy
//  simultaneously — while the render engine reported zero ring
//  underflows (the gap is upstream of the ring). Acquiring blocks on a
//  queue that does nothing else makes delivery immune to message-loop
//  congestion without adding any buffering (= no added latency).
//
//  Threading: all state is confined to `queue`. The TeamTalk C API is
//  internally synchronized per client instance, so acquiring blocks here
//  while the message loop makes other TT_* calls is safe (the codebase
//  already calls TT functions from multiple queues, e.g. the prewarm
//  path). Ordering is preserved because this pump is the ONLY acquirer
//  for its stream keys and `OutputAudioRenderEngine.enqueueUser` hops to
//  a serial queue. `stop()` is synchronous: once it returns, no further
//  SDK calls are made — the controller relies on that during teardown.
//
//  The muxed stream (TT_MUXED_USERID, the pre-14.2 AEC reference
//  fallback) intentionally stays on the message loop: its consumer is
//  queue-confined and reference timing tolerates the loop's jitter.
//

import Foundation

final class AudioBlockPump {
    private let queue = DispatchQueue(label: "com.ttaccessible.audio-block-pump", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var instance: UnsafeMutableRawPointer?
    private weak var engine: OutputAudioRenderEngine?
    /// Remote users whose per-user block events are enabled (mirrors the
    /// controller's `perUserAudioEnabled`).
    private var userIDs: [Int32] = []
    /// Whether our OWN media-file stream (TT_LOCAL_USERID) is subscribed
    /// (mirrors the controller's `localMediaAudioEnabled`).
    private var localMediaEnabled = false

    /// ~4× the usual block cadence (~40 ms OPUS frames): a queued block never
    /// waits long, and a tick on an empty queue is just a lock + check per
    /// enabled stream.
    private let tickMS = 10
    /// Safety bound per (user, stream) per tick; normal traffic is 1–2 blocks.
    private let maxBlocksPerStreamPerTick = 16

    /// Begin pumping for `instance`, feeding decoded PCM into `engine`.
    /// Synchronous so the user set pushed right after lands on a running pump.
    func start(instance: UnsafeMutableRawPointer, engine: OutputAudioRenderEngine) {
        queue.sync {
            stopTimerLocked()
            self.instance = instance
            self.engine = engine
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now() + .milliseconds(tickMS),
                           repeating: .milliseconds(tickMS), leeway: .milliseconds(2))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }

    /// Synchronous: after this returns the pump makes no further SDK calls.
    func stop() {
        queue.sync {
            stopTimerLocked()
            instance = nil
            engine = nil
            userIDs = []
            localMediaEnabled = false
        }
    }

    /// Reconcile the drained user set. Departed users' mix sources are removed
    /// HERE (not by the controller) so removal is ordered after this pump's
    /// final enqueue for that user — no ghost source can be recreated by a
    /// block acquired in the same tick.
    func setUsers(_ users: Set<Int32>) {
        queue.async { [weak self] in
            guard let self else { return }
            let departed = Set(self.userIDs).subtracting(users)
            self.userIDs = Array(users)
            if let engine = self.engine {
                for userID in departed {
                    engine.removeUser(userID)
                    engine.removeUser(TeamTalkConnectionController.outputMediaSourceKey(userID))
                }
            }
        }
    }

    /// Toggle draining of our own streamed media file (same ordering guarantee
    /// as `setUsers` for the source's removal).
    func setLocalMediaEnabled(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            let wasEnabled = self.localMediaEnabled
            self.localMediaEnabled = enabled
            if wasEnabled, enabled == false {
                self.engine?.removeUser(TeamTalkConnectionController.localMediaEngineKey)
            }
        }
    }

    private func stopTimerLocked() {
        timer?.cancel()
        timer = nil
    }

    private func tick() {
        guard let instance, let engine else { return }
        for userID in userIDs {
            drain(instance: instance, engine: engine, userID: userID,
                  streamType: STREAMTYPE_VOICE, engineKey: userID, profile: .network)
            drain(instance: instance, engine: engine, userID: userID,
                  streamType: STREAMTYPE_MEDIAFILE_AUDIO,
                  engineKey: TeamTalkConnectionController.outputMediaSourceKey(userID), profile: .network)
        }
        if localMediaEnabled {
            drain(instance: instance, engine: engine, userID: TT_LOCAL_USERID,
                  streamType: STREAMTYPE_MEDIAFILE_AUDIO,
                  engineKey: TeamTalkConnectionController.localMediaEngineKey, profile: .localMedia)
        }
    }

    /// Acquire every queued block for one (user, stream) and hand the PCM to the
    /// mix engine (which hops to its own serial queue).
    private func drain(
        instance: UnsafeMutableRawPointer,
        engine: OutputAudioRenderEngine,
        userID: Int32,
        streamType: StreamType,
        engineKey: Int32,
        profile: OutputSourceBufferProfile
    ) {
        var drained = 0
        while drained < maxBlocksPerStreamPerTick,
              let block = TT_AcquireUserAudioBlock(instance, UInt32(streamType.rawValue), userID) {
            drained += 1
            let frames = Int(block.pointee.nSamples)
            let channels = Int(block.pointee.nChannels)
            let sampleRate = Int(block.pointee.nSampleRate)
            if frames > 0, channels > 0, sampleRate > 0, let rawAudio = block.pointee.lpRawAudio {
                // Copy the SDK PCM out before the block is released — the engine
                // consumes it asynchronously on its own queue.
                let samplePtr = rawAudio.assumingMemoryBound(to: Int16.self)
                let pcm = Array(UnsafeBufferPointer(start: samplePtr, count: frames * channels))
                engine.enqueueUser(
                    engineKey,
                    pcm: pcm,
                    frames: frames, channels: channels, sampleRate: Double(sampleRate),
                    profile: profile
                )
            }
            TT_ReleaseUserAudioBlock(instance, block)
        }
    }
}
