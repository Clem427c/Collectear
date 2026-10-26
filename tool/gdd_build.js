const pptxgen = require("pptxgenjs");
const React = require("react");
const ReactDOMServer = require("react-dom/server");
const sharp = require("sharp");
const fa = require("react-icons/fa6");
const { applyTheme } = require("/mnt/skills/public/pptx/scripts/apply_theme.js");

const HEX = {
  ink: "1B1440", night: "2A1F5C", violet: "7B5CFF", gold: "FFB627",
  teal: "2EC4B6", coral: "FF6B6B", mist: "F3F1FA", white: "FFFFFF", text: "2B2A33", muted: "6B6880",
};
const THEME = {
  name: "GDD Cartes", headFontFace: "Arial", bodyFontFace: "Arial",
  colors: {
    dk1: HEX.text, lt1: HEX.white, dk2: HEX.ink, lt2: HEX.mist,
    accent1: HEX.violet, accent2: HEX.gold, accent3: HEX.teal, accent4: HEX.coral,
    accent5: HEX.night, accent6: HEX.muted, hlink: HEX.violet, folHlink: HEX.night,
  },
};

async function icon(name, color) {
  const svg = ReactDOMServer.renderToStaticMarkup(React.createElement(fa[name], { color: "#" + color, size: 256 }));
  const buf = await sharp(Buffer.from(svg)).resize(256, 256).png().toBuffer();
  return "image/png;base64," + buf.toString("base64");
}

(async () => {
  const pres = new pptxgen();
  pres.layout = "LAYOUT_16x9";
  pres.title = "GDD – Jeu mobile d'exploration et de cartes";
  pres.theme = { headFontFace: "Arial", bodyFontFace: "Arial" };
  const C = pres.SchemeColor;

  pres.defineSlideMaster({
    title: "DARK", background: { color: C.text2 },
    objects: [
      { placeholder: { options: { name: "title", type: "title", x: 0.6, y: 1.7, w: 8.8, h: 1.2, fontSize: 40, bold: true, color: C.background1, align: "left", valign: "bottom" }, text: "" } },
      { placeholder: { options: { name: "body", type: "body", x: 0.6, y: 3.0, w: 8.8, h: 0.8, fontSize: 18, color: C.accent2, align: "left", valign: "top" }, text: "" } },
    ],
  });
  pres.defineSlideMaster({
    title: "CONTENT", background: { color: C.background1 },
    objects: [
      { placeholder: { options: { name: "title", type: "title", x: 0.5, y: 0.3, w: 9, h: 0.75, fontSize: 30, bold: true, color: C.text2, align: "left", valign: "middle" }, text: "" } },
    ],
    slideNumber: { x: 9.2, y: 5.2, w: 0.5, h: 0.3, fontSize: 10, color: C.accent6 },
  });

  const card = (s, x, y, w, h, fill = C.background2) =>
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y, w, h, fill: { color: fill }, line: { color: fill }, rectRadius: 0.12 });
  const circleIcon = async (s, name, x, y, d, bg, fg = HEX.white) => {
    s.addShape(pres.shapes.OVAL, { x, y, w: d, h: d, fill: { color: bg }, line: { color: bg } });
    s.addImage({ data: await icon(name, fg), x: x + d * 0.25, y: y + d * 0.25, w: d * 0.5, h: d * 0.5 });
  };
  const txt = (s, t, o) => s.addText(t, Object.assign({ isTextBox: true, margin: 0, color: C.text1, fontSize: 14, valign: "top" }, o));

  // 1. Titre
  pres.addSection({ title: "Introduction" });
  let s = pres.addSlide({ masterName: "DARK", sectionTitle: "Introduction" });
  s.addText("Collectear", { placeholder: "title" });
  s.addText("Explore. Débloque. Collectionne. · GDD v0.5 · jeu mobile Flutter", { placeholder: "body" });
  for (let i = 0; i < 3; i++) {
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 7.2 + i * 0.55, y: 0.5 + i * 0.12, w: 1.1, h: 1.5, rotate: -12 + i * 12, fill: { color: [C.accent1, C.accent3, C.accent2][i] }, line: { color: C.background1, width: 2 }, rectRadius: 0.1 });
  }
  s.addImage({ data: await icon("FaStar", HEX.ink), x: 8.55, y: 1.0, w: 0.5, h: 0.5 });

  // 2. Pitch
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Introduction" });
  s.addText("Le concept en une phrase", { placeholder: "title" });
  card(s, 0.5, 1.2, 9, 1.0, C.text2);
  txt(s, "Collectear : un jeu d'exploration-action où l'on collectionne des créatures et des héros originaux, chacun unique, en runs de 2 minutes dans un monde infini, nouveau à chaque run.", { x: 0.75, y: 1.3, w: 8.5, h: 0.8, color: C.background1, fontSize: 16, valign: "middle" });
  const pillars = [
    ["FaCompass", "Explorer", "Un monde infini et aléatoire, différent à chaque partie, où des lieux cachés attendent d'être trouvés.", HEX.teal],
    ["FaLayerGroup", "Collectionner", "Chaque lieu débloqué donne une créature ou un héros, en variante unique. Objectif : compléter le bestiaire.", HEX.gold],
    ["FaUserGroup", "Partager", "Ajouter des amis, échanger ses cartes, s'affronter et comparer ses records d'exploration.", HEX.violet],
  ];
  for (let i = 0; i < 3; i++) {
    const x = 0.5 + i * 3.1;
    card(s, x, 2.5, 2.8, 2.6);
    await circleIcon(s, pillars[i][0], x + 0.25, 2.75, 0.65, pillars[i][3]);
    txt(s, pillars[i][1], { x: x + 0.25, y: 3.55, w: 2.3, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
    txt(s, pillars[i][2], { x: x + 0.25, y: 3.95, w: 2.35, h: 1.05, fontSize: 12 });
  }
  s.addNotes("Différenciation : la collection est alimentée par une phase d'exploration-action dans un monde procédural infini, et chaque créature obtenue est une variante unique. Univers 100 % original, donc aucun problème de licence.");

  // 3. Boucle de gameplay
  pres.addSection({ title: "Gameplay" });
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Boucle de gameplay", { placeholder: "title" });
  const loop = [
    ["FaMapLocationDot", "Explorer", "le monde généré", HEX.teal],
    ["FaHandFist", "Survivre", "combattre / esquiver", HEX.coral],
    ["FaLockOpen", "Débloquer", "un lieu caché", HEX.violet],
    ["FaGift", "Obtenir", "créature · héros", HEX.gold],
    ["FaRightLeft", "Utiliser", "échange · bataille", HEX.night],
  ];
  for (let i = 0; i < loop.length; i++) {
    const x = 0.5 + i * 1.86;
    await circleIcon(s, loop[i][0], x + 0.38, 1.45, 0.9, loop[i][3]);
    txt(s, loop[i][1], { x, y: 2.5, w: 1.66, h: 0.35, fontSize: 16, bold: true, align: "center", color: C.text2 });
    txt(s, loop[i][2], { x, y: 2.85, w: 1.66, h: 0.35, fontSize: 12, align: "center", color: C.accent6 });
    if (i < loop.length - 1) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + 1.42, y: 1.77, w: 0.32, h: 0.26, fill: { color: C.accent6 }, line: { color: C.accent6 } });
  }
  card(s, 0.5, 3.55, 9, 1.5);
  txt(s, [
    { text: "Boucle courte (2 min max) : ", options: { bold: true, color: C.text2 } },
    { text: "une run = explorer son monde, gagner jusqu'à 3 cartes, puis retour au menu. Plusieurs runs par jour, le temps d'une pause.", options: { breakLine: true } },
    { text: "Boucle longue : ", options: { bold: true, color: C.text2 } },
    { text: "compléter le bestiaire, chasser les variantes rares, échanger, monter son équipe pour les combats entre amis." },
  ], { x: 0.75, y: 3.7, w: 8.5, h: 1.2, fontSize: 14, paraSpaceAfter: 6, valign: "middle" });

  // 3b. Déroulé d'une run
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Une run : 2 minutes maximum", { placeholder: "title" });
  const run = [
    ["FaMobileScreen", "Menu", "bestiaire, amis, boutique", HEX.night],
    ["FaStopwatch", "Run", "chrono de 2:00", HEX.teal],
    ["FaGift", "Cartes", "ennemis · lieux", HEX.gold],
    ["FaFlag", "Fin de run", "voir ci-dessous", HEX.coral],
    ["FaStar", "Récap", "nouvelles cartes et stats", HEX.violet],
  ];
  for (let i = 0; i < run.length; i++) {
    const x = 0.5 + i * 1.86;
    await circleIcon(s, run[i][0], x + 0.43, 1.25, 0.8, run[i][3], i === 2 ? HEX.ink : HEX.white);
    txt(s, run[i][1], { x, y: 2.15, w: 1.66, h: 0.35, fontSize: 15, bold: true, align: "center", color: C.text2 });
    txt(s, run[i][2], { x, y: 2.48, w: 1.66, h: 0.3, fontSize: 11, align: "center", color: C.accent6 });
    if (i < run.length - 1) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + 1.42, y: 1.52, w: 0.32, h: 0.26, fill: { color: C.accent6 }, line: { color: C.accent6 } });
  }
  card(s, 0.5, 3.0, 4.4, 2.05);
  txt(s, "3 façons de finir une run", { x: 0.75, y: 3.12, w: 4, h: 0.35, fontSize: 15, bold: true, color: C.text2 });
  txt(s, [
    { text: "Mort ", options: { bold: true } }, { text: "du personnage", options: { breakLine: true } },
    { text: "3 cartes ", options: { bold: true } }, { text: "collectionnées : run réussie", options: { breakLine: true } },
    { text: "Chrono ", options: { bold: true } }, { text: "de 2 minutes écoulé", options: { breakLine: true } },
    { text: "Dans tous les cas, les cartes obtenues sont conservées.", options: { italic: true, color: C.accent6 } },
  ], { x: 0.75, y: 3.5, w: 3.95, h: 1.5, fontSize: 12, paraSpaceAfter: 5 });
  card(s, 5.1, 3.0, 4.4, 2.05);
  txt(s, "2 façons d'obtenir une carte", { x: 5.35, y: 3.12, w: 4, h: 0.35, fontSize: 15, bold: true, color: C.text2 });
  txt(s, [
    { text: "Tuer 10 ennemis ", options: { bold: true } }, { text: "pendant la run", options: { breakLine: true } },
    { text: "La trouver dans un lieu ", options: { bold: true } }, { text: "(sanctuaire, tour, ruine, coffre)", options: { breakLine: true } },
    { text: "Pensé pour des sessions courtes, lancées plusieurs fois par jour (pause au travail, transports).", options: { italic: true, color: C.accent6 } },
  ], { x: 5.35, y: 3.5, w: 3.95, h: 1.5, fontSize: 12, paraSpaceAfter: 5 });

  // 4. Monde procédural
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Un monde infini, généré procéduralement", { placeholder: "title" });
  // grille de chunks
  const gx = 0.5, gy = 1.3, cs = 0.62;
  const cols = [HEX.mist, "DDF5F2", "E7E1FF", "FFF0CC"];
  for (let r = 0; r < 6; r++) for (let c = 0; c < 6; c++) {
    const col = cols[(r * 7 + c * 3 + (r * c) % 2) % 4];
    s.addShape(pres.shapes.RECTANGLE, { x: gx + c * cs, y: gy + r * cs, w: cs - 0.04, h: cs - 0.04, fill: { color: col }, line: { color: col } });
  }
  s.addShape(pres.shapes.OVAL, { x: gx + 2 * cs + 0.13, y: gy + 3 * cs + 0.13, w: 0.32, h: 0.32, fill: { color: C.accent1 }, line: { color: C.accent1 } });
  for (const [c, r] of [[0, 1], [4, 0], [5, 4], [1, 5]]) s.addImage({ data: await icon("FaStar", HEX.gold), x: gx + c * cs + 0.14, y: gy + r * cs + 0.14, w: 0.3, h: 0.3 });
  s.addShape(pres.shapes.RECTANGLE, { x: gx + 1 * cs - 0.02, y: gy + 2 * cs - 0.02, w: cs * 3, h: cs * 3, fill: { color: C.background1, transparency: 100 }, line: { color: C.accent1, width: 1.5, dashType: "dash" } });
  txt(s, "Joueur au centre · zone chargée en pointillés · ★ lieux à découvrir", { x: 0.5, y: 5.05, w: 3.8, h: 0.3, fontSize: 10, color: C.accent6 });
  const world = [
    ["Chunks", "Le monde est découpé en zones chargées autour du joueur et déchargées derrière lui : infini sans saturer la mémoire du téléphone."],
    ["Nouveau monde à chaque run", "Chaque run génère un nouveau monde à partir d'une nouvelle seed. Ni partagé, ni conservé."],
    ["Biomes & niveaux de hauteur", "Bruit (Perlin/Simplex) pour les biomes et pour la hauteur, découpée en niveaux (voir diapo suivante)."],
    ["Difficulté par distance", "Plus on s'éloigne du départ en 2 minutes, plus les ennemis sont forts et les variantes rares : prise de risque."],
  ];
  for (let i = 0; i < world.length; i++) {
    txt(s, world[i][0], { x: 4.6, y: 1.3 + i * 0.95, w: 4.9, h: 0.3, fontSize: 15, bold: true, color: C.text2 });
    txt(s, world[i][1], { x: 4.6, y: 1.6 + i * 0.95, w: 4.9, h: 0.6, fontSize: 12 });
  }

  // 4b. Vue de dessus et niveaux
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Vue de dessus et niveaux de hauteur", { placeholder: "title" });
  // coupe du terrain en paliers
  const lv = [0, 1, 1, 2, 3, 3, 2, 1, 0, 0];
  const bx = 0.5, by = 4.45, bw = 0.45, bh = 0.6;
  const lvCol = ["DDF5F2", "B9EAE3", "97DED4", "6FCFC2"];
  for (let i = 0; i < lv.length; i++) {
    for (let k = 0; k <= lv[i]; k++) {
      s.addShape(pres.shapes.RECTANGLE, { x: bx + i * bw, y: by - k * bh, w: bw - 0.02, h: bh - 0.02, fill: { color: lvCol[k] }, line: { color: lvCol[k] } });
    }
  }
  for (let k = 0; k < 4; k++) txt(s, "Niv. " + k, { x: bx + lv.length * bw + 0.08, y: by - k * bh + 0.18, w: 0.6, h: 0.25, fontSize: 10, color: C.accent6 });
  s.addShape(pres.shapes.OVAL, { x: bx + 2 * bw + 0.1, y: by - 2 * bh + 0.05, w: 0.26, h: 0.26, fill: { color: C.accent1 }, line: { color: C.accent1 } });
  s.addShape(pres.shapes.CURVED_UP_ARROW, { x: bx + 2 * bw + 0.15, y: by - 3 * bh + 0.05, w: 0.6, h: 0.45, fill: { color: C.accent2 }, line: { color: C.accent2 } });
  txt(s, "Vue en coupe pour illustrer ; en jeu, la caméra est au-dessus et les niveaux se lisent par les ombres et les bords de falaise.", { x: 0.5, y: 5.0, w: 5.0, h: 0.4, fontSize: 10, color: C.accent6 });
  const hs = [
    ["Caméra", "Vue de dessus (top-down), le personnage se déplace dans les 8 directions."],
    ["Niveaux de hauteur", "Chaque case du monde a un niveau (0, 1, 2…) calculé par bruit : collines, plateaux, falaises, tous générés."],
    ["Saut = +1 niveau", "Un saut permet de monter d'un seul niveau. Se laisser tomber permet de redescendre."],
    ["Level design", "Les lieux et coffres se cachent sur des plateaux à atteindre par une suite de sauts."],
  ];
  for (let i = 0; i < hs.length; i++) {
    txt(s, hs[i][0], { x: 6.0, y: 1.2 + i * 1.0, w: 3.5, h: 0.3, fontSize: 15, bold: true, color: C.text2 });
    txt(s, hs[i][1], { x: 6.0, y: 1.5 + i * 1.0, w: 3.5, h: 0.65, fontSize: 12 });
  }

  // 5. Actions du personnage
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Actions du personnage", { placeholder: "title" });
  const acts = [
    ["FaPersonRunning", "Se déplacer", "Joystick virtuel à gauche de l'écran. Déplacement fluide, caméra qui suit le joueur.", HEX.teal],
    ["FaAnglesUp", "Sauter", "Monter d'un niveau de hauteur ; enchaîner les sauts pour atteindre plateaux et lieux cachés.", HEX.violet],
    ["FaHandFist", "Attaquer", "Combat en temps réel contre les créatures et ennemis IA. Combo simple possible plus tard.", HEX.coral],
    ["FaShieldHalved", "Esquiver", "Roulade ou dash avec courte invincibilité et temps de recharge, pour éviter les attaques.", HEX.gold],
  ];
  for (let i = 0; i < 4; i++) {
    const x = 0.5 + (i % 2) * 4.6, y = 1.3 + Math.floor(i / 2) * 1.55;
    card(s, x, y, 4.4, 1.35);
    await circleIcon(s, acts[i][0], x + 0.25, y + 0.3, 0.75, acts[i][3]);
    txt(s, acts[i][1], { x: x + 1.2, y: y + 0.2, w: 3.0, h: 0.35, fontSize: 16, bold: true, color: C.text2 });
    txt(s, acts[i][2], { x: x + 1.2, y: y + 0.55, w: 3.0, h: 0.7, fontSize: 12 });
  }
  txt(s, "Contrôles tactiles : joystick à gauche, trois boutons à droite (sauter · attaquer · esquiver).", { x: 0.5, y: 4.55, w: 9, h: 0.4, fontSize: 13, italic: true, color: C.accent6 });

  // 6. Ennemis IA
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Ennemis (IA)", { placeholder: "title" });
  const states = [["Patrouille", HEX.teal], ["Détection", HEX.gold], ["Poursuite", HEX.violet], ["Attaque annoncée", HEX.coral]];
  for (let i = 0; i < 4; i++) {
    const x = 0.5 + i * 2.3;
    s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x, y: 1.35, w: 1.95, h: 0.7, fill: { color: states[i][1] }, line: { color: states[i][1] }, rectRadius: 0.12 });
    txt(s, states[i][0], { x, y: 1.35, w: 1.95, h: 0.7, fontSize: 14, bold: true, align: "center", valign: "middle", color: i === 1 ? C.text2 : C.background1 });
    if (i < 3) s.addShape(pres.shapes.RIGHT_ARROW, { x: x + 1.99, y: 1.58, w: 0.27, h: 0.24, fill: { color: C.accent6 }, line: { color: C.accent6 } });
  }
  txt(s, "Machine à états simple pour chaque ennemi ; retour en patrouille si le joueur s'éloigne.", { x: 0.5, y: 2.15, w: 9, h: 0.3, fontSize: 11, color: C.accent6 });
  card(s, 0.5, 2.7, 4.4, 2.35);
  txt(s, "Principes", { x: 0.75, y: 2.85, w: 4, h: 0.35, fontSize: 16, bold: true, color: C.text2 });
  txt(s, [
    { text: "Attaques télégraphiées (signal visuel avant le coup) pour rendre l'esquive lisible", options: { bullet: true, breakLine: true } },
    { text: "Ennemis générés avec le monde, densité selon le biome", options: { bullet: true, breakLine: true } },
    { text: "Combats en temps réel ; un ennemi tombe en 3 coups", options: { bullet: true } },
  ], { x: 0.75, y: 3.25, w: 3.95, h: 1.7, fontSize: 12, paraSpaceAfter: 6 });
  card(s, 5.1, 2.7, 4.4, 2.35);
  txt(s, "Deux types d'ennemis", { x: 5.35, y: 2.85, w: 4, h: 0.35, fontSize: 16, bold: true, color: C.text2 });
  txt(s, [
    { text: "Corps à corps : ", options: { bold: true } }, { text: "s'approche et frappe", options: { breakLine: true } },
    { text: "Tir à distance : ", options: { bold: true } }, { text: "garde ses distances et tire des projectiles", options: { breakLine: true } },
    { text: "Pas de mini-boss ni de boss.", options: { italic: true, color: C.accent6 } },
  ], { x: 5.35, y: 3.25, w: 3.95, h: 1.7, fontSize: 12, paraSpaceAfter: 6 });

  // 6b. Compagnon de run
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Gameplay" });
  s.addText("Compagnon de run", { placeholder: "title" });
  txt(s, "Avant chaque run, le joueur choisit une créature ou un héros de sa collection. Il l'accompagne et lui donne un boost.", { x: 0.5, y: 1.1, w: 9, h: 0.45, fontSize: 14 });
  const boosts = [
    ["FaHandFist", "Dégâts", "Un ennemi tombe en 2 coups au lieu de 3.", HEX.coral],
    ["FaPersonRunning", "Vitesse", "Déplacement plus rapide pour couvrir plus de terrain.", HEX.teal],
    ["FaShieldHalved", "Résistance", "Le joueur encaisse 3 coups au lieu de 2.", HEX.violet],
    ["FaStopwatch", "Temps", "+30 secondes au chrono : la run dure 2:30.", HEX.gold],
  ];
  for (let i = 0; i < 4; i++) {
    const x = 0.5 + i * 2.3;
    card(s, x, 1.7, 2.1, 2.35);
    await circleIcon(s, boosts[i][0], x + 0.2, 1.9, 0.65, boosts[i][3], i === 3 ? HEX.ink : HEX.white);
    txt(s, boosts[i][1], { x: x + 0.2, y: 2.7, w: 1.75, h: 0.35, fontSize: 16, bold: true, color: C.text2 });
    txt(s, boosts[i][2], { x: x + 0.2, y: 3.1, w: 1.75, h: 0.85, fontSize: 12 });
  }
  card(s, 0.5, 4.25, 9, 0.8, C.text2);
  txt(s, "Règles de base : un ennemi meurt en 3 coups ; le joueur meurt au 2e coup reçu, ce qui met fin à la run.", { x: 0.75, y: 4.28, w: 8.5, h: 0.74, fontSize: 13, color: C.background1, valign: "middle" });

  // 7. Lieux & récompenses
  pres.addSection({ title: "Collection" });
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Collection" });
  s.addText("Lieux à découvrir et récompenses", { placeholder: "title" });
  const places = [
    ["Sanctuaire", "Vaincre les ennemis qui l'entourent", HEX.coral],
    ["Tour", "Monter en sautant de plateforme en plateforme", HEX.violet],
    ["Ruine", "Trouver l'entrée cachée ou résoudre une petite énigme", HEX.teal],
    ["Coffre rare", "Apparaît loin du départ ; meilleures chances de variante rare", HEX.gold],
  ];
  for (let i = 0; i < 4; i++) {
    const y = 1.25 + i * 0.75;
    s.addShape(pres.shapes.OVAL, { x: 0.5, y: y + 0.1, w: 0.42, h: 0.42, fill: { color: places[i][2] }, line: { color: places[i][2] } });
    txt(s, places[i][0], { x: 1.1, y: y + 0.03, w: 4, h: 0.3, fontSize: 15, bold: true, color: C.text2 });
    txt(s, places[i][1], { x: 1.1, y: y + 0.33, w: 4, h: 0.3, fontSize: 12 });
  }
  s.addChart(pres.charts.BAR, [{ name: "Probabilité", labels: ["Commune", "Peu commune", "Rare", "Épique", "Légendaire"], values: [60, 25, 10, 4, 1] }], {
    x: 5.4, y: 1.15, w: 4.1, h: 3.4, barDir: "bar", showTitle: true, title: "Rareté des créatures (exemple, %)", titleFontSize: 12, titleColor: HEX.ink, titleFontFace: "+mn-lt",
    showValue: true, dataLabelPosition: "outEnd", dataLabelFontSize: 10, dataLabelColor: HEX.text, dataLabelFontFace: "+mn-lt",
    chartColors: [HEX.violet], showLegend: false, catAxisLabelColor: HEX.muted, valAxisLabelColor: HEX.muted, catAxisLabelFontSize: 10, valAxisLabelFontSize: 9,
    catAxisLabelFontFace: "+mn-lt", valAxisLabelFontFace: "+mn-lt", valGridLine: { color: "E4E1EE", size: 0.5 }, catGridLine: { style: "none" }, catAxisOrientation: "maxMin", valAxisMaxVal: 70,
  });
  txt(s, "Taux indicatifs, à équilibrer en playtest. Les lieux éloignés améliorent les chances.", { x: 5.4, y: 4.6, w: 4.1, h: 0.4, fontSize: 10, color: C.accent6 });

  // 8. Collection de cartes
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Collection" });
  s.addText("Le bestiaire : créatures et héros originaux", { placeholder: "title" });
  // maquette carte
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.7, y: 1.25, w: 2.4, h: 3.5, fill: { color: C.text2 }, line: { color: C.accent2, width: 3 }, rectRadius: 0.15 });
  s.addShape(pres.shapes.ROUNDED_RECTANGLE, { x: 0.9, y: 1.7, w: 2.0, h: 1.6, fill: { color: C.accent5 }, line: { color: C.accent5 }, rectRadius: 0.08 });
  s.addImage({ data: await icon("FaPaw", HEX.gold), x: 1.6, y: 2.2, w: 0.6, h: 0.6 });
  txt(s, "Nom de la créature", { x: 0.9, y: 1.35, w: 2.0, h: 0.3, fontSize: 12, bold: true, color: C.background1 });
  txt(s, "★★★ Rare · Biome forêt", { x: 0.9, y: 3.4, w: 2.0, h: 0.3, fontSize: 11, color: C.accent2, bold: true });
  txt(s, "ATQ 7 · DEF 4 · PV 12", { x: 0.9, y: 3.75, w: 2.0, h: 0.3, fontSize: 10, color: C.background1 });
  txt(s, "N° 042 / 150", { x: 0.9, y: 4.3, w: 2.0, h: 0.3, fontSize: 9, color: C.accent6 });
  const coll = [
    ["Créatures et héros", "Deux familles originales, chacune avec illustration, nom, biome, rareté, stats et numéro dans le bestiaire."],
    ["Bestiaire", "Cases manquantes en silhouette pour donner envie de compléter ; chaque biome a ses espèces."],
    ["Compagnon de run", "Chaque carte peut accompagner le joueur pendant une run et lui donner un boost."],
    ["300+ de base", "Au moins 300 créatures et héros différents, sans compter les variantes et shiny générés. Doublons échangeables."],
  ];
  for (let i = 0; i < 4; i++) {
    txt(s, coll[i][0], { x: 3.6, y: 1.25 + i * 0.9, w: 5.9, h: 0.3, fontSize: 15, bold: true, color: C.text2 });
    txt(s, coll[i][1], { x: 3.6, y: 1.55 + i * 0.9, w: 5.9, h: 0.55, fontSize: 12 });
  }
  txt(s, "Inspirations : Pokémon (capture et compagnon), Pokémon TCG et Wikimasters (collection)", { x: 3.6, y: 4.85, w: 5.9, h: 0.3, fontSize: 10, italic: true, color: C.accent6 });

  // 8b. Variantes et découvreur
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Collection" });
  s.addText("Variantes uniques et profil d'explorateur", { placeholder: "title" });
  card(s, 0.5, 1.25, 4.4, 2.85);
  await circleIcon(s, "FaDice", 0.75, 1.45, 0.6, HEX.gold, HEX.ink);
  txt(s, "Variantes procédurales", { x: 1.5, y: 1.55, w: 3.3, h: 0.4, fontSize: 17, bold: true, color: C.text2 });
  txt(s, [
    { text: "Chaque carte est générée à partir de la seed du monde et du lieu", options: { bullet: true, breakLine: true } },
    { text: "Couleurs, motifs, traits et stats légèrement différents", options: { bullet: true, breakLine: true } },
    { text: "Shiny et variantes rares (dorée, cristal, ombre…) : un exemplaire peut être unique", options: { bullet: true, breakLine: true } },
    { text: "Moteur des échanges : on cherche la variante qu'on n'a pas", options: { bullet: true } },
  ], { x: 0.75, y: 2.15, w: 3.95, h: 1.85, fontSize: 12, paraSpaceAfter: 5 });
  card(s, 5.1, 1.25, 4.4, 2.85);
  await circleIcon(s, "FaFlag", 5.35, 1.45, 0.6, HEX.violet);
  txt(s, "Profil d'explorateur", { x: 6.1, y: 1.55, w: 3.3, h: 0.4, fontSize: 17, bold: true, color: C.text2 });
  txt(s, [
    { text: "Chacun explore son propre monde : pas de monde partagé", options: { bullet: true, breakLine: true } },
    { text: "Profil visible par les amis : lieux découverts, record de distance, variantes rares", options: { bullet: true, breakLine: true } },
    { text: "Classement des explorateurs entre amis", options: { bullet: true, breakLine: true } },
    { text: "Partage de ses plus belles trouvailles", options: { bullet: true } },
  ], { x: 5.35, y: 2.15, w: 3.95, h: 1.85, fontSize: 12, paraSpaceAfter: 5 });
  card(s, 0.5, 4.3, 9, 0.75, C.text2);
  txt(s, "Pourquoi ça attire : rareté réelle, envie de montrer sa trouvaille, utilité en combat, collection à compléter.", { x: 0.75, y: 4.33, w: 8.5, h: 0.7, fontSize: 13, color: C.background1, valign: "middle" });

  // 8c. Production des visuels
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Collection" });
  s.addText("Production des visuels", { placeholder: "title" });
  card(s, 0.5, 1.25, 4.4, 2.85);
  await circleIcon(s, "FaLayerGroup", 0.75, 1.45, 0.6, HEX.violet);
  txt(s, "Illustrations de base : IA", { x: 1.5, y: 1.55, w: 3.3, h: 0.4, fontSize: 17, bold: true, color: C.text2 });
  txt(s, [
    { text: "300+ créatures et héros générés par IA", options: { bullet: true, breakLine: true } },
    { text: "Fiche de style fixe (prompt de base, palette, cadrage) pour une DA cohérente", options: { bullet: true, breakLine: true } },
    { text: "Retouche humaine sur chaque image", options: { bullet: true, breakLine: true } },
    { text: "Vérifier les CGU de l'outil pour l'usage commercial", options: { bullet: true } },
  ], { x: 0.75, y: 2.15, w: 3.95, h: 1.85, fontSize: 12, paraSpaceAfter: 5 });
  card(s, 5.1, 1.25, 4.4, 2.85);
  await circleIcon(s, "FaDice", 5.35, 1.45, 0.6, HEX.gold, HEX.ink);
  txt(s, "Variantes : code procédural", { x: 6.1, y: 1.55, w: 3.3, h: 0.4, fontSize: 17, bold: true, color: C.text2 });
  txt(s, [
    { text: "La seed fixe les paramètres de chaque variante", options: { bullet: true, breakLine: true } },
    { text: "Teinte et palette via shader ou ColorFilter dans Flutter", options: { bullet: true, breakLine: true } },
    { text: "Motifs et effets shiny en surcouche (reflets, particules)", options: { bullet: true, breakLine: true } },
    { text: "Taille et stats légèrement modifiées", options: { bullet: true } },
  ], { x: 5.35, y: 2.15, w: 3.95, h: 1.85, fontSize: 12, paraSpaceAfter: 5 });
  card(s, 0.5, 4.3, 9, 0.75, C.text2);
  txt(s, "Attention : une image 100 % IA n'est pas protégée par le droit d'auteur aux États-Unis, et sans doute pas en France sans apport humain réel. La retouche et le dépôt de la marque protègent le projet.", { x: 0.75, y: 4.32, w: 8.5, h: 0.71, fontSize: 12, color: C.background1, valign: "middle" });

  // 9. Social
  pres.addSection({ title: "Social et compte" });
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Social et compte" });
  s.addText("Compte, amis, échanges et combats", { placeholder: "title" });
  const soc = [
    ["FaUserPlus", "Compte joueur", ["Inscription e-mail ou Google / Apple", "Collection sauvegardée en ligne", "Même compte sur mobile et navigateur"], HEX.teal],
    ["FaUserGroup", "Amis", ["Ajout par code ami ou pseudo", "Voir le bestiaire d'un ami", "Liste de souhaits partagée"], HEX.violet],
    ["FaRightLeft", "Échanges", ["Créature contre créature", "Validation par les deux joueurs", "Limites anti-abus (par jour, rareté)"], HEX.gold],
    ["FaFire", "Combats", ["Entre amis, avec ses cartes", "Format en réflexion", "Mis de côté pour l'instant"], HEX.coral],
  ];
  for (let i = 0; i < 4; i++) {
    const x = 0.5 + i * 2.3;
    card(s, x, 1.25, 2.1, 3.8);
    await circleIcon(s, soc[i][0], x + 0.2, 1.45, 0.6, soc[i][3]);
    txt(s, soc[i][1], { x: x + 0.2, y: 2.15, w: 1.75, h: 0.35, fontSize: 15, bold: true, color: C.text2 });
    txt(s, soc[i][2].map((t, j) => ({ text: t, options: { bullet: true, breakLine: j < soc[i][2].length - 1 } })), { x: x + 0.2, y: 2.6, w: 1.8, h: 2.3, fontSize: 12, paraSpaceAfter: 6 });
  }

  // 10. Monétisation
  pres.addSection({ title: "Business et technique" });
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Business et technique" });
  s.addText("Monétisation", { placeholder: "title" });
  card(s, 0.5, 1.25, 4.4, 2.75);
  await circleIcon(s, "FaRectangleAd", 0.75, 1.45, 0.6, HEX.violet);
  txt(s, "Publicités", { x: 1.5, y: 1.55, w: 3.2, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Vidéos récompensées (optionnelles) : run bonus au-delà de 10 par jour, résurrection", options: { bullet: true, breakLine: true } },
    { text: "Interstitiels rares, jamais pendant une run", options: { bullet: true, breakLine: true } },
    { text: "Option payante « sans pub »", options: { bullet: true } },
  ], { x: 0.75, y: 2.2, w: 3.95, h: 1.7, fontSize: 12, paraSpaceAfter: 6 });
  card(s, 5.1, 1.25, 4.4, 2.75);
  await circleIcon(s, "FaShirt", 5.35, 1.45, 0.6, HEX.gold, HEX.ink);
  txt(s, "Skins", { x: 6.1, y: 1.55, w: 3.2, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Apparences du personnage explorateur", options: { bullet: true, breakLine: true } },
    { text: "Cadres de fiches, effets visuels, accessoires de créatures", options: { bullet: true, breakLine: true } },
    { text: "Purement cosmétique : aucun avantage en jeu", options: { bullet: true } },
  ], { x: 5.35, y: 2.2, w: 3.95, h: 1.7, fontSize: 12, paraSpaceAfter: 6 });
  card(s, 0.5, 4.2, 9, 0.85, C.text2);
  txt(s, "Ligne rouge : pas de pay-to-win, pas de vente de créatures ou de boosters contre de l'argent réel (cadre légal des loot boxes à surveiller).", { x: 0.75, y: 4.25, w: 8.5, h: 0.75, fontSize: 13, color: C.background1, valign: "middle" });

  // 11. Stack technique
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Business et technique" });
  s.addText("Architecture technique", { placeholder: "title" });
  const tech = [
    ["FaMobileScreen", "Client Flutter", "Flutter + Flame (moteur 2D pour Flutter) : rendu, collisions, entrées tactiles. Interface hors-jeu (bestiaire, amis, boutique) en widgets Flutter classiques.", HEX.teal],
    ["FaServer", "Backend", "Firebase ou Supabase : authentification, base de données (collection, amis, échanges), fonctions serveur pour valider les récompenses.", HEX.violet],
    ["FaRectangleAd", "Services", "Google AdMob (pubs), achats intégrés App Store / Google Play (skins, sans pub), analytics.", HEX.gold],
    ["FaGlobe", "Web (plus tard)", "Flutter Web pour une version navigateur, même code et même compte.", HEX.coral],
  ];
  for (let i = 0; i < 4; i++) {
    const y = 1.2 + i * 0.95;
    await circleIcon(s, tech[i][0], 0.5, y + 0.05, 0.6, tech[i][3], i === 2 ? HEX.ink : HEX.white);
    txt(s, tech[i][1], { x: 1.3, y, w: 2.2, h: 0.7, fontSize: 15, bold: true, color: C.text2, valign: "middle" });
    txt(s, tech[i][2], { x: 3.5, y, w: 6.0, h: 0.75, fontSize: 12, valign: "middle" });
  }
  txt(s, "Règle d'or : le serveur décide des récompenses et des échanges, jamais le téléphone (anti-triche).", { x: 0.5, y: 5.0, w: 9, h: 0.3, fontSize: 11, italic: true, color: C.accent6 });

  // 12. IP
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Business et technique" });
  s.addText("Un univers 100 % original", { placeholder: "title" });
  card(s, 0.5, 1.25, 4.4, 3.8);
  await circleIcon(s, "FaShieldHalved", 0.75, 1.45, 0.6, HEX.teal);
  txt(s, "Pourquoi", { x: 1.5, y: 1.55, w: 3.2, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Aucun risque de droit d'auteur ou de marque sur des personnages tiers", options: { bullet: true, breakLine: true } },
    { text: "Aucune licence à payer, pas de retrait des stores sur plainte", options: { bullet: true, breakLine: true } },
    { text: "Marque « Collectear » et noms de créatures déposables", options: { bullet: true } },
  ], { x: 0.75, y: 2.2, w: 3.95, h: 2.6, fontSize: 13, paraSpaceAfter: 8 });
  card(s, 5.1, 1.25, 4.4, 3.8);
  await circleIcon(s, "FaPuzzlePiece", 5.35, 1.45, 0.6, HEX.violet);
  txt(s, "À faire", { x: 6.1, y: 1.55, w: 3.2, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Vérifier que les noms de créatures et du jeu ne sont pas déjà des marques (bases INPI / EUIPO)", options: { bullet: true, breakLine: true } },
    { text: "Garder une trace datée des créations (ex. enveloppe Soleau INPI)", options: { bullet: true, breakLine: true } },
    { text: "Déposer la marque du jeu avant le lancement", options: { bullet: true, breakLine: true } },
    { text: "Ne pas imiter de créatures existantes de trop près", options: { bullet: true } },
  ], { x: 5.35, y: 2.2, w: 3.95, h: 2.6, fontSize: 13, paraSpaceAfter: 8 });

  // 13. Décisions
  pres.addSection({ title: "Suite" });
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Suite" });
  s.addText("Décisions prises", { placeholder: "title" });
  card(s, 0.5, 1.25, 4.4, 3.8);
  await circleIcon(s, "FaGamepad", 0.75, 1.45, 0.6, HEX.teal);
  txt(s, "Gameplay", { x: 1.5, y: 1.55, w: 3.2, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Vue de dessus ; un saut = +1 niveau de hauteur", options: { bullet: true, breakLine: true } },
    { text: "Combats en temps réel, 2 types d'ennemis, pas de boss", options: { bullet: true, breakLine: true } },
    { text: "Nouveau monde à chaque run", options: { bullet: true, breakLine: true } },
    { text: "Run de 2 min ; fin : mort, 3 cartes ou chrono", options: { bullet: true, breakLine: true } },
    { text: "Carte : 10 ennemis tués ou trouvée dans un lieu", options: { bullet: true, breakLine: true } },
    { text: "Compagnon de run avec un boost", options: { bullet: true } },
  ], { x: 0.75, y: 2.2, w: 3.95, h: 2.75, fontSize: 12, paraSpaceAfter: 4 });
  card(s, 5.1, 1.25, 4.4, 3.8);
  await circleIcon(s, "FaFlag", 5.35, 1.45, 0.6, HEX.violet);
  txt(s, "Contenu et business", { x: 6.1, y: 1.55, w: 3.3, h: 0.4, fontSize: 18, bold: true, color: C.text2 });
  txt(s, [
    { text: "Titre : Collectear", options: { bullet: true, breakLine: true } },
    { text: "Créatures ET héros, 300+ de base", options: { bullet: true, breakLine: true } },
    { text: "Illustrations IA + variantes procédurales par code", options: { bullet: true, breakLine: true } },
    { text: "3 cartes max par run, 10 runs par jour", options: { bullet: true, breakLine: true } },
    { text: "Pubs + skins cosmétiques, pas de pay-to-win", options: { bullet: true, breakLine: true } },
    { text: "Univers 100 % original", options: { bullet: true } },
  ], { x: 5.35, y: 2.2, w: 3.95, h: 2.75, fontSize: 12, paraSpaceAfter: 4 });

  // 13b. Questions restantes
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Suite" });
  s.addText("Questions restantes", { placeholder: "title" });
  const qs = [
    "Format des combats entre amis (en réflexion, mis de côté)",
    "Le compteur de 10 ennemis repart-il à zéro à chaque run ?",
    "Quel boost porte chaque carte : fixé par espèce ou tiré au sort par variante ?",
    "Héros et créatures : quelle différence en dehors du boost ?",
    "Direction artistique : style imposé à l'IA",
    "Disponibilité de la marque « Collectear » (INPI, EUIPO, stores)",
  ];
  for (let i = 0; i < qs.length; i++) {
    const x = 0.5 + (i % 2) * 4.6, y = 1.25 + Math.floor(i / 2) * 1.25;
    card(s, x, y, 4.4, 1.05);
    await circleIcon(s, "FaCircleQuestion", x + 0.2, y + 0.25, 0.55, HEX.violet);
    txt(s, qs[i], { x: x + 0.95, y: y + 0.1, w: 3.3, h: 0.85, fontSize: 13, valign: "middle" });
  }

  // 14. Roadmap
  s = pres.addSlide({ masterName: "CONTENT", sectionTitle: "Suite" });
  s.addText("Feuille de route", { placeholder: "title" });
  const road = [
    ["1", "Prototype", "Déplacement, saut, attaque, esquive ; chunks ; 2 ennemis ; chrono 2 min"],
    ["2", "Boucle de jeu", "Lieux, déblocage, créatures de test, variantes, bestiaire local"],
    ["3", "En ligne", "Comptes, sauvegarde serveur, amis, échanges"],
    ["4", "Monétisation", "AdMob, skins, achats intégrés ; bêta fermée"],
    ["5", "Lancement", "Collectear : 300+ cartes, stores, puis web ; combats entre amis ensuite"],
  ];
  s.addShape(pres.shapes.LINE, { x: 0.9, y: 2.0, w: 8.2, h: 0, line: { color: C.accent6, width: 2 } });
  for (let i = 0; i < road.length; i++) {
    const x = 0.5 + i * 1.86;
    const col = [HEX.teal, HEX.violet, HEX.gold, HEX.coral, HEX.ink][i];
    s.addShape(pres.shapes.OVAL, { x: x + 0.53, y: 1.7, w: 0.6, h: 0.6, fill: { color: col }, line: { color: C.background1, width: 2 } });
    txt(s, road[i][0], { x: x + 0.53, y: 1.7, w: 0.6, h: 0.6, fontSize: 16, bold: true, align: "center", valign: "middle", color: i === 2 ? C.text2 : C.background1 });
    txt(s, road[i][1], { x, y: 2.55, w: 1.7, h: 0.35, fontSize: 15, bold: true, align: "center", color: C.text2 });
    txt(s, road[i][2], { x: x + 0.05, y: 2.95, w: 1.6, h: 1.6, fontSize: 12, align: "center" });
  }
  txt(s, "Objectif de l'étape 1 : valider que se déplacer et se battre dans le monde est fun, avant tout le reste.", { x: 0.5, y: 4.75, w: 9, h: 0.4, fontSize: 13, italic: true, color: C.accent6 });

  await pres.writeFile({ fileName: "GDD.pptx" });
  await applyTheme("GDD.pptx", THEME);
  console.log("ok");
})();
