## v1.7.0-beta.5 (build 36) — 2026-06-22

Ceci est une version **bêta**, destinée à tester de nouveaux changements avant leur diffusion à tout le monde. Pour recevoir les mises à jour bêta, activez **Inclure les versions bêta** dans Préférences › Général.

## Corrections

- **La connexion web BearWare n'échoue plus avec « réponse inattendue ».** La connexion à un serveur avec votre compte BearWare pouvait échouer par intermittence avec l'erreur « Le service de connexion BearWare a renvoyé une réponse inattendue » et interrompre la connexion. La connexion se déroule désormais comme dans le client officiel — un incident côté service BearWare ne vous bloque plus, et si un serveur refuse réellement le compte, vous obtenez un message clair. Les indications des réglages renvoient aussi désormais vers **Préférences › BearWare** (au lieu de Général).

## Aussi dans cette bêta

- **VoiceOver annonce davantage de changements de contrôles.** VoiceOver énonce la nouvelle valeur immédiatement lorsque vous ajustez les curseurs des préférences Notifications et Annonces, et annonce l'état du microphone lorsque vous activez ou désactivez la transmission.
- **VoiceOver annonce les changements de volume.** Lorsque vous ajustez les curseurs de gain du microphone ou de volume de sortie, VoiceOver énonce la nouvelle valeur immédiatement au lieu de répéter la précédente. Merci à Gabriel pour le signalement.
- **Lancement plus rapide.** L'application marquait une pause au démarrage. Cette pause a disparu — ttaccessible s'ouvre désormais immédiatement.
- **Vider votre pseudo ne vous déconnecte plus.** Lorsque vous changez votre pseudo (F5) et laissez le champ vide, ttaccessible utilise désormais votre pseudo par défaut des réglages au lieu d'afficher l'erreur « Le pseudo ne peut pas être vide ».
- **Connectez-vous avec un compte BearWare.** Connectez-vous aux serveurs qui utilisent la connexion web BearWare (bearware.dk) sans créer de compte distinct sur chacun. Configurez votre compte BearWare gratuit une seule fois dans **Préférences › BearWare**, puis activez **Utiliser la connexion web BearWare** pour chaque serveur qui la prend en charge. Cette fonctionnalité cherche encore des testeurs — vos retours sont les bienvenus via Aide › Contacter le développeur.

## Installation

Si vous avez activé les mises à jour bêta, ttaccessible installera cette mise à jour pour vous — aucune action nécessaire.

Installation manuelle :

1. Téléchargez `ttaccessible-1.7.0-beta.5-36.zip` ci-dessous.
2. Décompressez l'archive et glissez `ttaccessible.app` dans votre dossier `/Applications`, en remplaçant la version précédente.
3. Double-cliquez — aucun avertissement Gatekeeper grâce à la notarisation.
