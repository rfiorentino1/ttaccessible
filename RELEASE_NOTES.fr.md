## v1.7.0-beta.9 (build 40) — 2026-06-28

Ceci est une version **bêta**, destinée à tester les nouveautés avant leur diffusion à tout le monde. Pour recevoir les mises à jour bêta, activez **Inclure les versions bêta** dans Préférences › Général.

### À la une
- **Les volumes par utilisateur restent à leur place.** Le volume, la balance et la position panoramique que vous réglez pour une personne ne débordent plus d'un serveur à l'autre — ni sur quelqu'un d'autre qui utiliserait le même identifiant.
- **C'est vous qui décidez de ce qui est retenu.** Un nouveau réglage permet de conserver ces volumes pour toujours, le temps d'une session seulement, ou pas du tout.

### Nouveautés

**Les volumes par utilisateur sont désormais propres à chaque serveur.** Certains ont remarqué des personnes à des volumes étranges — trop fortes ou trop faibles — sans y avoir jamais touché. La raison : un niveau réglé pour un nom de compte était réutilisé pour quiconque portait ce même nom, y compris sur des serveurs totalement différents. (Les serveurs publics partagent souvent des identifiants génériques comme `guest`.) Le volume, la balance stéréo et le panoramique sont maintenant rattachés au serveur où vous les avez réglés : un niveau défini sur un serveur y reste.

**Choisissez comment ces volumes sont mémorisés.** Préférences › Audio comporte un nouveau réglage **Mémorisation des volumes par utilisateur**, avec trois choix :

- **Désactivé** — rien n'est retenu ; à la reconnexion, tout le monde revient à 50 %, comme dans le client officiel.
- **Session en cours seulement** — vos réglages durent tant que l'app est ouverte, puis repartent à zéro à la fermeture.
- **Toujours** (par défaut) — vos réglages sont conservés d'un lancement à l'autre, par serveur.

Vous pouvez changer de mode à tout moment, l'effet est immédiat.

### Bon à savoir
À cause du correctif ci-dessus, les volumes par utilisateur que vous aviez enregistrés sont remis à zéro une fois lors de cette mise à jour et repartent à 50 % — ces anciennes valeurs étaient justement les données mêlées entre serveurs que l'on nettoie. Il vous suffira de régler à nouveau les quelques personnes qui comptent pour vous.

## Installation

Si vous avez activé les mises à jour bêta, tt-Accessible installera cette mise à jour pour vous — aucune action nécessaire.

Installation manuelle :

1. Téléchargez `ttaccessible-1.7.0-beta.9-40.zip` ci-dessous.
2. Décompressez l'archive et glissez `ttaccessible.app` dans votre dossier `/Applications`, en remplaçant la version précédente.
3. Double-cliquez — aucun avertissement Gatekeeper grâce à la notarisation.
