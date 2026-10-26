# Collectear – fiche de style des illustrations

## Direction artistique
**Cartoon coloré et rond, façon jeu mobile grand public.**
- Formes rondes et dodues, silhouettes simples et lisibles même en petit.
- Contours sombres épais et nets, ombrage doux en aplats (cel shading).
- Couleurs vives et saturées, grands yeux expressifs, expressions joyeuses.
- Un seul personnage, en pied, centré, vue de 3/4 face, **fond blanc uni**.
- **Créatures** : non humanoïdes (animaux, esprits élémentaires). **Héros** : humanoïdes, proportions « chibi ».
- La rareté se lit dans la mise en scène : communes = bébés tout mignons ; peu communes = jeunes plus assurés ;
  rares = formes évoluées avec un détail distinctif ; épiques = pose dynamique et lueur magique ;
  légendaires = pose héroïque, aura rayonnante, détails ornés.
- Designs **100 % originaux** : ne jamais imiter Pokémon, Digimon ou tout autre personnage existant.

## Prompts
Les 300 prompts (en anglais) sont dans `docs/prompts_illustrations.csv` (séparateur `;`), avec le
**prompt négatif** commun à coller dans le champ « negative prompt » quand l'outil en propose un.
Conseil : générer d'abord 5–6 cartes de raretés différentes pour valider le style, puis réutiliser la même
« seed » / le même style de référence pour garder une cohérence sur les 300.

## Livraison des images
1. Nommer chaque image par son numéro de carte : `001.png`, `042.png`, `300.png` (PNG ou JPG acceptés).
2. Les déposer dans le dossier **`art/raw/`** du dépôt GitHub (sur github.com : ouvrir `art/raw`,
   « Add file » → « Upload files », glisser les images, « Commit changes »).
3. C'est tout : la CI retire le fond blanc, recadre, redimensionne en 512×512 et intègre l'image au jeu.
   Les variantes (teinte, finitions Dorée/Cristal/Ombre, shiny) sont appliquées automatiquement par le jeu.

Pour un bon détourage automatique : fond **blanc uni**, personnage entouré d'un contour sombre fermé.
La petite ombre ronde au sol est voulue (choix de Clem) : elle est conservée par le détourage.

## Droit d'auteur
Une image 100 % générée par IA est peu ou pas protégée. Retoucher chaque image (couleurs, détails,
expression) renforce la protection, tout comme le dépôt de la marque Collectear et des noms de cartes.
Vérifier que les conditions d'utilisation de l'outil d'IA autorisent l'usage commercial.
