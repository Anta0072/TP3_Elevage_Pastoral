
*=============================================================
* CONFIGURATION DES CHEMINS — À MODIFIER PAR CHAQUE UTILISATEUR
* Modifiez UNIQUEMENT la ligne global root avec votre chemin racine
*=============================================================

global root      "C:\Users\ndaoa\Documents\ISEP2\Statistiques agricoles\TP3"  // ← changer ici

* Les chemins suivants se construisent automatiquement — NE PAS MODIFIER
global inputfile "$root\data\raw\famille_troupeau.dta"      // données brutes (.dta)
global data      "$root\data\cleaned"  // données nettoyées
global codes     "$root\scripts"       // scripts .do

*=============================================================
* FIN DE LA CONFIGURATION
*=============================================================

***-----------------------------------
*********************************************
***			Préparation des données
*********************************************

* Import master dataset
* Cette ligne charge la base de données de départ. Cette ligne est primordiale car on ne peut pas travailler sans les données. Cependant, une ligne de code déclarant la variable inputfile devrait précéder cette ligne car autrement ce code ne marchera pas
use "${inputfile}", clear  

***-----------------------------------
*		 1. explorer dataset
* Ce code donne la structure de la base de données : observations, variables. 
	describe , short

	
*********************************************
***			BLOC 1 : Commentaire
*********************************************
 /* Le Bloc 1 a pour objectif de renommer la variable d'identification des ménages en ID, supprimer les observations où la valeur de ID est manquante, de supprimer les doublons, de créer une variable country représentant le pays d'origine des ménages et de corriger les incohérences liées aux pays. */
 

***-----------------------------------
*		 2. variable ID
***-----------------------------------

	*rename ID var : Ici on renomme la variable Codeduquestionnaire en ID puis on regarde les caractéristiques de ID. Ce code permet de simplifier le nom de cette variable et de faire un premier repérage de potentielles incohérences sur la variable ID. Si on ne l'appliquait pas il se peut qu'en écrivant le nom de la variable qu'on fasse des erreurs de frappes ou qu'on ne fasse des erreurs de traitement car ne connaissant pas les caractéristiques de la variable ID.
	ren Codeduquestionnaire ID
	codebook ID

	* drop missing ID : On supprime les observations où la valeur de ID est manquante. Ce code est nécessaire car les lignes n'ayant pas de valeur pour ID n'ont pas de grande utilité dans la base. Si on ne l'appliquait pas cela pourrait biaiser les résultats des analyses faites sur cette base.
	drop if missing(ID)

	* deal with real ID duplicates : On cherche s'il y a des doublons dans la colonne ID puis on créée une variable qui détecte les doublons. Ce code permet de connaitre le nombre d'observations ne présentant pas de doublons et les observations qui présentent des doublons ainsi que le nombre d'occurence des doublons pour chaque observation. Si on n'applique pas, on ne peut pas connaître le nombre de doublons ainsi que leur répartition.
	duplicates report  ID
	duplicates tag ID, gen(duplicates)
	*br if duplicates : On supprime les lignes où il y a des doublons en utilisant la variable détectrice de doublons créée ci-dessus. Cette opération permet de supprimer les informations redondantes. Si on ne l'appliquait pas le code on aurait travaillé sur la base en utilisant toutes ses données alors que l'information que la base doit donner n'est concrètement détenue que par une partie de celle-ci, l'autre partie pouvant être supprimée.
	duplicates drop ID if duplicates, force
	drop duplicates

	* Ici on vérifie s'il ne reste pas de doublons. Si on ne le fait pas il se peut qu'il y ait encore des doublons dans la base ce qui pourrait biaiser les calculs
	isid ID

***-----------------------------------
*		3.1 generate LOCATIONs from ID
***-----------------------------------
	* check ID length : Ici, on transforme la variable ID en string puis on vérifie la longueur de chaque modalité de ID. Cette étape est un préliminaire pour l'opération suivante où on doit extraire le code des pays à partir des ID. Sans cette opération, on ne pourra pas extraire des parties des modalités de ID car celles-ci sont des nombres.
	tostring ID, replace
	gen id_length = length(ID)
	tab id_length // all ok, 6 characters as expected
	drop id_length

	* gen country : On crée unz variable country représentant les pays à partir de la variable ID transformée en string. On prend le premier caractère de ID, on visualise la partie de la base avec seulement les variables ID, country, Zonederéférence, DépartementouCercle et Région mais on remarque qu'il y a des incohérences entre les variables Région et country. Pour corriger ces problèmes, on transforme country en nombre ou pouvoir sélectionner les observations où country est supérieur à 5. Cette phase est importante pour la correction des incohérences dans la variable country.
	gen country = substr(ID, 1, 1)
	list ID country Zonederéférence DépartementouCercle Région
	destring country, replace
	list country Groupedorigine Région DépartementouCercle if country>5
	* cross-check with Region
// 	forvalues num = 4/8 {
// 		tab Région if country==`num', mis		
// 	} 

	* label country : On labélise les modalités de country en affectant à chaque modalité un pays donné. Cette opération permet de donner un sens aux résultats trouvés pour une modalité donné. Si on ne  l'appliquait pas l'interprétation des résultats aurait été difficile
	lab def country 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger"
	lab val country country
	
	* now changing the values : On corrige les incohérences entre country et Région. En effet, il y avait des régions qui étaient affectées à des pays auxquels elles ne correspondaient pas. Si on ne l'appliquait pas les résultats n'auraient pas été bons.
	replace country=2 if Région=="kayes"
	replace country=5 if Région=="Tillabery"
	replace country=4 if Région=="Sahel" | Région=="Est"
	
	* drop unnecessary variables : On supprime les variables qui ne sont pas nécessaire à l'analyse qu'on souhaite mener et on réorganise certaines variables dans la base.
	drop Ordredesaisie PAYS Zonederéférence Groupedorigine
	order ID country Région
	
* Save cleaned ID : On enregistre la nouvelle base en réduisant la taille de la base en mémoire. Cette partie permet de mettre à jour la base et garder au moins cette partie du traitement dans le cas où on perd ses données.
	compress
	save "${data}/FT_cleanID.dta", replace

***-----------------------------------
*		 3.2  composition du ménage
***-----------------------------------

*********************************************
***			BLOC 2 : Commentaire
*********************************************
/* Le bloc 2 a pour objectif de traiter les variables de composition interne de la base. Il sort les caractéristiques de ces variables, de constituer une taille cohérente des ménages (taille réel et taille en équivalent adulte)*/


* On cherche les caractéristiques des variables de composition des ménages. Ca nous permet de connaitre la composition globale des familles. Si on ne faisait oas cette étape, on travaillerait "à l'aveugle" sur des données potentiellement corrompues.
codebook HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 Nombretotaldepersonnes

* Après le code précédent on voit qu'il n'y a pas de concordance entre le nombre total de personnes et la composition interne des ménages. On supprime donc la variable Nombretotaldepersonnes et on crée une nouvelle variable en faisant la somme des nombres de membres.
drop Nombretotaldepersonnes 

egen HHsize =rsum(HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12)

* On inspecte les caractéristiques de la nouvelle variable créée puis on la croise avec la variable Région pour voir des paramètres comme la moyenne, l'écart-type, la médiane, la minimum, le maximum et le nombre d'observation. Ce code permet d'avoir une vue globale sur la répartition des individus des ménages par régions
codebook HHsize
tabstat HHsize, by(Région) s(mean sd p50 min max n)

* On crée une boucle qui va explorer toutes les variables de composition interne des ménages pour remplacer les valeurs manquantes par 0. Laissez les valeurs manquantes comme ça aurait faussé les calculs faits sur ces variables
foreach var of varlist HommesadultesHA FemmesadultesFA VieuxV Garçonsde12ansG12 Fillesde12ansF12 {

replace `var'=0 if missing(`var')

}

* On crée une variable qui donne la taille du ménage en équivalent adulte en considérant que les enfants de moins de 12 ans représentent 3/4 d'adulte. Etant donné que les enfants ne consomment pas de la même manière que les adultes, ce code permet de d'estimer de manière plus pertinente les besoins des ménages. Sans ça on sous-estimerait ou sur-estimerait les besoins réels du ménage.
gen HHsizeEA = HommesadultesHA + FemmesadultesFA+ VieuxV +0.5*(Garçonsde12ansG12+Fillesde12ansF12)

compress
save "${data}/FT_cleanMenage.dta", replace

***-----------------------------------
*		 4. VENTES betail
***-----------------------------------
*********************************************
***			BLOC 4 : Commentaire
*   Ce bloc fait quoi ?
*     Recharge la base pivot, isole les variables de ventes,
*     traite une valeur texte parasite ("sendré"), restructure
*     de wide à long (un animal vendu par ligne), puis nettoie
*     et harmonise chaque variable : sexe, âge, origine, date,
*     lieu d'achat, prix. Les prix aberrants sont mis à manquant
*     puis imputés par la moyenne du groupe.
*
*   Pourquoi est-il nécessaire ?
*     Les données de ventes arrivent en format wide (jusqu'à 14
*     animaux par ménage en colonnes). Ce format est inexploitable
*     pour des analyses statistiques : impossible de calculer
*     un prix moyen, une saisonnalité ou une distribution par sexe
*     sans passer en long. Les variables contiennent également des
*     incohérences de codage (M/F vs 1/2, "Famille" vs "1") qui
*     empêchent toute agrégation.
*
*   Que se passerait-il sans ce bloc ?
*     Les ventes resteraient en format wide, inexploitables.
*     Les analyses de prix, saisonnalité et stratégies de vente
*     seraient impossibles.
*********************************************
* ----------------------------------------------------
* Cette ligne recharge la base pivot FT_cleanID.dta en écrasant tout ce qui est en mémoire.Pourquoi ? Ce bloc travaille sur un sous-ensemble différent des variables (ventes), distinct du bloc ménage. Sans cette ligne, on travaillerait sur les données ménage encore en mémoire. Ce "use ... clear" est précisément ce qui efface HHsize et HHsizeEA — elles ne seront jamais sauvegardées nulle part.
* ----------------------------------------------------
	use "${data}/FT_cleanID.dta", clear


*** Tidying the sales dataset
	** subset 
* ----------------------------------------------------
* Cette ligne ne conserve que ID, country et toutes les variables de ventes (Sexe*, Age*,Origine*, Mois*, Année*, Aqui*, Où*, Prix*). Les * sont des wildcards. Pourquoi ? Réduit la base au strict nécessaire avant le reshape ; moins de variables = reshape plus rapide et lisible. Sans cette ligne ?Toutes les variables non-ventes (géographie détaillée, composition ménage) seraient dupliquées autant de fois qu'il y a d'animaux par ménage après le reshape
* ----------------------------------------------------
	keep ID country Sexe* Age* Origine* Mois* Année* Aqui* Où* Prix*
* ----------------------------------------------------
* Cette ligne supprime les variables Années* (avec s final). Pourquoi ?Le wildcard Année* du keep précédent a capturé à la fois Année (année de vente, voulue) et Années (autre variable, non voulue). Ce drop corrige la sur-capture du wildcard. Sans cette ligne ?   Années* serait intégrée dans le reshape, créant une variable parasite "Années" dans la base longue.
* ----------------------------------------------------
	drop Années*
	** Harmonize the variables 
* ----------------------------------------------------
*Cette ligne convertit TOUTES les variables en string. Pourquoi ?Les variables wide ont des types hétérogènes(certaines numériques, d'autres déjà string). Le reshape long exige un type homogène pour chaque groupe de variables (Sexe1…Sexe50 doivent toutes être du même type). Passer tout en string garantit cette homogénéité avant le reshape. Sans cette ligne ?Le reshape planterait avec une erreur de type si Sexe37 est numérique et Sexe38 est string.
* ----------------------------------------------------
	tostring *, replace
* ----------------------------------------------------
*Boucle sur les animaux 37 à 50 : pour chaque animal dont le Prix contient "sendré", liste les valeurs puis impute toutes les variables avec des valeurs fixes (Sexe=1, Age=2, Origine=1, Mois=4, Année=2015, Aqui=1, Où="sendré", Prix=45000). Pourquoi ?              "sendré" est visiblement un nom propre (acheteur ou lieu) saisi dans le champ Prix par erreur. Les vraies valeurs de cet animal sont connues de l'enquêteur et imputées ici. Sans cette ligne ?Prix="sendré" ne peut pas être converti en numérique ; destring produirait un NA pour cet animal.
* Décisions très discutables :
*   - Les valeurs imputées (Sexe=1 mâle, Age=2 ans, Prix=45000 FCFA, Mois=4 avril)
*     semblent issues de la connaissance terrain de l'enquêteur mais ne sont
*     documentées nulle part dans le script. Leur source est intraçable.
*   - La boucle couvre les animaux 37 à 50 uniquement. Si "sendré" apparaît
*     dans des colonnes 1 à 36, il ne serait pas traité.
*   - Où="sendré" est conservé tel quel, mais Où sera droppé plus loin —
*     ce sous-traitement est donc sans effet pour cette variable.
* ----------------------------------------------------	
forvalues num = 37/50 {
 // Affiche les valeurs de l'animal `num` quand Prix vaut "sendré" — contrôle visuel
	list Sexe`num' Age`num' Origine`num' Mois`num' Année`num' Aqui`num' Où`num' Prix`num' if Prix`num'=="sendré"
// Impute Sexe à "1" (mâle) pour cet animal — valeur arbitraire non documentée
	replace Sexe`num' = "1" if Prix`num' == "sendré"
// Impute Age à "2" (ans) — valeur arbitraire non documentée
    replace Age`num' = "2" if Prix`num' == "sendré"
// Impute Origine à "1" (Famille) — valeur arbitraire non documentée
    replace Origine`num' = "1" if Prix`num' == "sendré"
// Impute Mois à "4" (avril) — valeur arbitraire, pas de justification
    replace Mois`num' = "4" if Prix`num' == "sendré"
// Impute Année à "2015" — valeur arbitraire, pas de justification
    replace Année`num' = "2015" if Prix`num' == "sendré"
// Impute Aqui à "1" (marché bétail) — valeur arbitraire non documentée
    replace Aqui`num' = "1" if Prix`num' == "sendré"
// Maintient Où="sendré" — sans effet car Où sera droppé plus loin
    replace Où`num' = "sendré" if Prix`num' == "sendré"
 // Impute le prix à 45 000 FCFA — valeur qui semble raisonnable mais est non vérifiable
    replace Prix`num' = "45000" if Prix`num' == "sendré"		
	}



	** reshape long the data
* ----------------------------------------------------
* Cette ligne restructure la base de wide à long : chaque animal vendu devient une ligne distincte. i(ID) = identifiant ménage, j(animal_number) = rang de l'animal. Pourquoi ?    Format indispensable pour toute analyse statistique des ventes : distribution des prix, saisonnalité, comparaisons par sexe/âge/pays. Sans cette ligne ?Impossible d'analyser les ventes autrement qu'animal par animal en hard-codant chaque numéro de colonne
* ----------------------------------------------------
	reshape long Sexe Age Origine Mois Année Aqui Où Prix, i(ID) j(animal_number) 
* ----------------------------------------------------
* Que fait cette ligne ?  Supprime les lignes entièrement identiques sur les
*                         8 variables listées
* Pourquoi ?              Après le reshape, les ménages ayant vendu moins de 14
*                         animaux ont des lignes vides (toutes variables à NA
*                         ou à ""). Ces lignes "fantômes" sont des doublons
*                         parfaits entre elles.
* Sans cette ligne ?   La base contiendrait des milliers de lignes vides
*                         qui gonfleraient tous les effectifs
* Décision discutable : "force" supprime AUSSI de vrais doublons métier
*                         (deux animaux identiques en tous points vendus par
*                         le même ménage). Le commentaire original dit
*                         "to kill missing values" mais l'outil utilisé
*                         (duplicates drop) est trop large : il élimine
*                         toute ligne strictement identique, pas seulement
*                         les lignes vides. Un "drop if missing(Prix)"
*                         aurait été plus ciblé et moins destructeur.
* ----------------------------------------------------
	*duplicates drop Sexe Age Origine Mois Année Aqui Où Prix, force //to kill missing values
	*On supprime les lignes vides
drop if Prix == "" | Prix == "."
*On voit les vrais doublons (sans ligne vide) puis on crée une variable vrai_doublon qui donne 0 si l'observation est unique et donne une valeur supérieure ou égale selon le nombre de fois que la ligne se répète.
duplicates report Sexe Age Origine Mois Année Aqui Prix
duplicates tag   Sexe Age Origine Mois Année Aqui Prix, gen(vrai_doublon)
browse if vrai_doublon > 0
*On regarde manuellement la base, on voit que toutes les lignes identiques ont le même ID donc c'est probablement une erreur de saisie. On supprime dons les vrais doublons.
drop vrai_doublon
	
	
	** clean different variables
		* sex
* ----------------------------------------------------
* Que fait cette ligne ?  Affiche les valeurs uniques et fréquences de Sexe
* Pourquoi ?              Révèle les modalités textuelles à harmoniser
*                         avant destring (ex. "M", "F", "1", "2", "male"…)
* Sans cette ligne ?      Aucun impact ; contrôle visuel omis
* ----------------------------------------------------
		codebook Sexe
* ----------------------------------------------------
* Que font ces 3 lignes ?  Harmonise les codes sexe :
*                          "F" → "2", "M" → "1",
*                          toute autre valeur → "" (manquant)
* Pourquoi ?              La variable contient des codes texte hétérogènes
*                         issus de saisies différentes ; destring ne peut
*                         convertir que "1" et "2"
* Sans ces lignes ?    destring produirait des NA pour "M" et "F",
*                         perdant des observations valides
* Décision discutable : toute valeur autre que "M", "F", "1", "2"
*                         est silencieusement mise à manquant. Des saisies
*                         légèrement différentes ("male", "m", "femelle")
*                         seraient perdues sans avertissement.
* ----------------------------------------------------
		replace Sexe="2" if Sexe=="F"
		replace Sexe="1" if Sexe=="M"
		replace Sexe="" if Sexe!="2" & Sexe!="1"
// Convertit Sexe en numérique après harmonisation
		destring Sexe, replace
// Définit les labels : 1=Male, 2=Female
		lab def Sexe 1 "Male" 2 "Female"
// Applique les labels à la variable Sexe
		lab val Sexe Sexe
// Vérifie la distribution finale de Sexe avec affichage des manquants
		tab Sexe, mis
		
		* Age
// Affiche les caractéristiques de Age avant transformation
		codebook Age
// Convertit Age en numérique (les valeurs non-numériques deviennent NA)
		destring Age, replace
// Tableau de fréquences pour détecter les valeurs aberrantes
		tab Age
* ----------------------------------------------------
* Que fait cette ligne ?  Décode la valeur 99 comme manquante (code enquête
*                         signifiant "ne sait pas" ou "non renseigné")
* Pourquoi ?              99 est une convention de codage pour les valeurs
*                         manquantes dans les enquêtes Stata ; le laisser
*                         biaiserait la moyenne d'âge vers le haut
* Sans cette ligne ?   Un âge de 99 ans serait traité comme une donnée
*                         valide, faussant toutes les analyses sur l'âge
* ----------------------------------------------------
		mvdecode Age, mv(99)
* ----------------------------------------------------
* Que fait cette ligne ?  Met à manquant tous les âges supérieurs à 20 ans
* Pourquoi ?              Un animal de bétail vendu à plus de 20 ans est
*                         biologiquement improbable — signe d'erreur de saisie
* Sans cette ligne ?   Des âges aberrants (ex. 45, 99 si mvdecode raté)
*                         resteraient et biaiseraient les moyennes
* Décision discutable : le seuil de 20 ans est posé sans justification
*                         dans le script. Certaines espèces (ânes, chameaux)
*                         peuvent légitimement dépasser 20 ans. Un seuil
*                         différencié par espèce serait plus rigoureux,
*                         mais l'espèce n'est pas une variable disponible ici.
* ----------------------------------------------------
		replace Age=. if Age >20 
		
		* Origine
// Affiche les valeurs uniques de Origine avant harmonisation
		codebook Origine
* ----------------------------------------------------
* Que fait cette ligne ?  Remplace la modalité textuelle "Famille" par "1"
* Pourquoi ?              La variable contient un mélange de codes numériques
*                         (1, 2) et de labels texte ("Famille") — il faut
*                         tout ramener à des codes numériques avant destring
* Sans cette ligne ?   "Famille" deviendrait NA après destring — perte
*                         d'observations valides
* Décision discutable : seule la modalité "Famille" est traitée en texte.
*                         Si d'autres modalités textuelles existent (ex. "Confié"
*                         en toutes lettres), elles passeraient à NA sans alerte.
*                         Le codebook préalable permet de le détecter, mais
*                         aucune correction n'est prévue pour "Confié".
* ----------------------------------------------------
		replace Origine="1" if Origine=="Famille"
// Convertit Origine en numérique
		destring Origine, replace
// Définit les labels : 1=Famille (élevé dans le ménage), 2=Confié (en gérance)
		lab def Origine 1 "Famille" 2 "Confié"
// Applique les labels
		lab val Origine Origine
// Applique les labels
		tab Origine, mis
		
		* Date de vente
// Affiche les valeurs uniques de Mois
		codebook Mois
// Tableau de fréquences des mois pour détecter des valeurs hors 1–12
		tab Mois
// Affiche les valeurs uniques d'Année
		codebook Année
* ----------------------------------------------------
* Que fait cette ligne ?  Remplace "2004" par "2014" dans la variable Année
* Pourquoi ?              "2004" est vraisemblablement une faute de frappe
*                         pour "2014" (l'enquête porte sur 2014–2015) ;
*                         conserver 2004 fausserait toute analyse temporelle
* Sans cette ligne ?   Une vente datée de 2004 resterait dans la base,
*                         décalant la distribution temporelle de 10 ans
* Décision discutable : la correction est appliquée à toutes les lignes
*                         avec Année=="2004" sans vérification contextuelle.
*                         Si l'enquête couvrait effectivement des ventes
*                         historiques, certains 2004 pourraient être valides.
*                         Aucune trace de cette correction dans le script.
* ----------------------------------------------------
		replace Année="2014" if Année=="2004"
// Convertit Mois en numérique
		destring Mois, replace
* ----------------------------------------------------
* Que fait cette ligne ?  Crée un indicateur binaire soudure=1 si la vente
*                         a eu lieu entre mai (5) et août (8)
* Pourquoi ?              La soudure (période de disette avant la récolte)
*                         est une variable analytique clé en pastoralisme :
*                         les familles vendent davantage d'animaux sous
*                         contrainte alimentaire pendant cette période.
*                         Cet indicateur permet de tester cet effet.
* Sans cette ligne ?   L'analyse de la saisonnalité des ventes serait
*                         limitée au mois brut, sans regroupement théorique
* ----------------------------------------------------
		gen soudure=inrange(Mois,5,8)
		
		* Aqui (to clean further)
// Affiche les valeurs uniques de Aqui
		codebook Aqui
// Tableau croisé Aqui × country pour détecter des hétérogénéités géographiques
		tab Aqui country
// Harmonise les modalités textuelles vers des codes numériques
		replace Aqui="1" if Aqui=="Marché bétail"
		replace Aqui="2" if Aqui=="Habitant local"
		replace Aqui="3" if Aqui=="Au campement"
* ----------------------------------------------------
* Que fait cette ligne ?  Met à manquant la modalité codée "4"
* Pourquoi ?              Le code "4" n'a pas de label défini dans le dictionnaire
*                         (qui ne va que jusqu'à 3) — sa signification est inconnue
* Sans cette ligne ?   "4" deviendrait un code numérique valide après destring
*                         mais sans label, créant une modalité fantôme dans les
*                         tableaux et graphiques
* Décision discutable : mettre "4" à manquant suppose qu'on ne sait pas ce
*                         qu'il signifie. Si c'est une quatrième modalité oubliée
*                         dans le questionnaire (ex. "vente à domicile"), on perd
*                         de l'information réelle. Le commentaire "to clean further"
*                         dans le code original suggère que l'auteur lui-même
*                         considère ce nettoyage incomplet.
* ----------------------------------------------------
		replace Aqui="" if Aqui=="4"
// Convertit Aqui en numérique
		destring Aqui, replace
// Définit les labels pour les 3 modalités connues
		lab def Aqui 1"sur un marché" 2"producteur local" 3"commerçant venu chez eux"
// Applique les labels
		lab val Aqui Aqui

		* Où
// Affiche les valeurs uniques de Où
		codebook Où
* ----------------------------------------------------
* Que fait cette ligne ?  Supprime entièrement la variable Où
* Pourquoi ?              Probablement trop hétérogène ou redondante avec Aqui
*                         pour être exploitable sans nettoyage lourd
* Sans cette ligne ?   Où resterait dans la base — encombrement sans usage
* Décision discutable : la variable est droppée sans avoir été inspectée
*                         au-delà du codebook. Elle pourrait contenir une
*                         information géographique sur la mobilité des ventes
*                         (vente dans le village vs. au marché distant) qui
*                         est analytiquement précieuse dans un contexte pastoral.
*                         Un résumé par pays avant drop aurait permis de trancher.
* ----------------------------------------------------
		drop Où
		
		* Prix
// Affiche les caractéristiques de Prix avant transformation
		codebook Prix
// Convertit Prix en numérique (valeurs non convertibles → NA)
		destring Prix, replace
// (désactivée) Aurait affiché une boîte à moustaches pour visualiser
// la distribution des prix et détecter les outliers
		*graph box Prix
* ----------------------------------------------------
* Que fait cette ligne ?  Met à manquant tous les prix hors de l'intervalle
*                         [20 000 ; 450 000] FCFA
* Pourquoi ?              Les prix en dehors de cette plage sont jugés
*                         biologiquement ou économiquement impossibles :
*                         moins de 20 000 FCFA serait sous le prix d'abattage,
*                         plus de 450 000 FCFA dépasserait le prix des meilleurs
*                         bovins sur les marchés sahéliens
* Sans cette ligne ?   Les outliers resteraient et biaiseraient fortement
*                         les moyennes et régressions (un prix à 9 000 000
*                         ou à 500 FCFA fausserait tout)
* Décision discutable : les bornes [20 000 ; 450 000] sont fixées
*                         arbitrairement sans documentation de leur source.
*                         Elles ne différencient pas les espèces (un âne
*                         et un chameau n'ont pas le même prix de marché).
*                         Des prix légitimes proches des bornes pourraient
*                         être exclus (ex. une chèvre à 18 000 FCFA).
* ----------------------------------------------------
		replace Prix=. if !inrange(Prix,20000,450000) 
* ----------------------------------------------------
* Que font ces 2 lignes ?  Pour chaque combinaison Sexe × Age × country,
*                          calcule la moyenne des prix valides, puis remplace
*                          les prix manquants par cette moyenne de groupe
* Pourquoi ?              Les prix mis à manquant (hors plage ou non saisie)
*                         doivent être imputés pour ne pas perdre ces
*                         observations dans les analyses. La moyenne de groupe
*                         est une imputation simple qui préserve les
*                         hétérogénéités par sexe, âge et pays.
*Sans ces lignes ?    Les animaux avec prix manquant seraient exclus
*                         des analyses sur les prix — biais d'exclusion
*Décisions discutables :
*   - Double imputation : les prix aberrants sont d'abord mis à NA
*     (ligne précédente) puis imputés ici. On ne peut plus distinguer
*     "prix manquant car non déclaré" de "prix exclu car aberrant".
*   - La moyenne simple est sensible aux outliers résiduels dans le groupe.
*     Une médiane aurait été plus robuste.
*   - Si un groupe (ex. femelles de 3 ans au Niger) n'a aucun prix valide,
*     mean_P sera NA et le prix restera manquant — cas non géré.
*   - Aucun flag ne signale les observations imputées, rendant impossible
*     une analyse de sensibilité ultérieure.
* ----------------------------------------------------
		*bys Sexe Age country : egen mean_P=mean(Prix) 
		*replace Prix=mean_P if missing(Prix)
		bys Sexe Age country : egen median_P = median(Prix)
		replace Prix = median_P if missing(Prix)
		drop median_P
// Supprime la variable de moyenne de groupe, devenue inutile après imputation
		

		
* compress and save
* ----------------------------------------------------
* Que font ces 2 lignes ?  Compressent les types de variables puis sauvegardent
*                          la base longue des ventes nettoyées
* Pourquoi ?              compress réduit la taille du fichier ; save produit
*                         la livrable de ce bloc, utilisée dans les analyses
* Sans ces lignes ?        Le travail de ce bloc serait perdu (comme le bloc 2)
* ----------------------------------------------------
compress
save "${data}/vente_betail_cleaned.dta", replace		


***===================================
*   BLOC 4 — ÉMIGRATION
*   (1. cleaning.do lignes 188–208 + emigration_cleaning.do)
*
*   Ce bloc fait quoi ?
*     Recharge la base pivot, isole les variables d'émigration,
*     restructure de wide à long (un migrant par ligne), supprime
*     les lignes vides, puis appelle un sous-script externe qui
*     harmonise les destinations textuelles libres en 11 grandes
*     zones géographiques et code le sens du déplacement
*     (dans le pays / dans le Sahel / hors Sahel).
*
*   Pourquoi est-il nécessaire ?
*     Les destinations sont saisies en texte libre (noms de villes,
*     de pays, d'abréviations locales) : impossible de les analyser
*     sans harmonisation. Le format wide rend impossible le calcul
*     d'indicateurs d'intensité migratoire par ménage.
*
*   Que se passerait-il sans ce bloc ?
*     Pas de variable de destination utilisable. Les stratégies de
*     migration des ménages pastoraux — complément de revenu clé
*     en période de stress — ne pourraient pas être étudiées.
***===================================

**-----------------------------------
*** 5. Emigration 
*-----------------------------------

* ----------------------------------------------------
* Que fait cette ligne ?  Recharge la base pivot FT_cleanID.dta en écrasant
*                         tout ce qui est en mémoire
* Pourquoi ?              Ce bloc travaille sur un sous-ensemble distinct
*                         des variables (émigration), indépendant des blocs
*                         ventes et ménage
* Sans cette ligne ?      On travaillerait sur la base ventes encore en mémoire
*                         depuis le bloc précédent
* ----------------------------------------------------
use "${data}/FT_cleanID.dta", clear

* ----------------------------------------------------
* Que fait cette ligne ?  Ne conserve que ID, country, Région et les 4 groupes
*                         de variables d'émigration (Liensdeparenté*, Endroit*,
*                         Années*, Activité*) — les * capturent tous les suffixes
* Pourquoi ?              Réduit la base au strict nécessaire avant le reshape ;
*                         Région est conservée (contrairement au bloc ventes)
*                         car la destination peut dépendre de la zone d'origine
* Sans cette ligne ?      Toutes les variables non-migration seraient dupliquées
*                         autant de fois qu'il y a de migrants par ménage
*                         après le reshape, alourdissant inutilement la base
* ----------------------------------------------------
keep ID country Région Liensdeparenté* Endroit* Années* Activité*

* ----------------------------------------------------
* Que fait cette ligne ?  Restructure de wide à long : chaque migrant du ménage
*                         devient une ligne. i(ID) = identifiant ménage,
*                         j(migr_number) = rang du migrant dans le ménage
* Pourquoi ?              Même logique que le bloc ventes : le format wide est
*                         inexploitable pour des analyses sur les migrants
*                         (nb de migrants, destinations, activités)
* Sans cette ligne ?   Impossible d'analyser les migrations autrement qu'en
*                         hard-codant chaque numéro de colonne
* Décision discutable : contrairement au bloc ventes, il n'y a pas de
*                         tostring * préalable. Les variables doivent donc
*                         déjà être de type homogène dans la base wide —
*                         à vérifier, sinon le reshape plante silencieusement
*                         en convertissant des numériques en string ou inversement
* ----------------------------------------------------
reshape long Liensdeparenté Endroit Années Activité, i(ID) j(migr_number)

* ----------------------------------------------------
* Que fait cette ligne ?  Supprime les lignes où les 3 variables substantielles
*                         sont simultanément manquantes
* Pourquoi ?              Après le reshape, les ménages avec peu de migrants
*                         génèrent des lignes vides. La condition triple (ET)
*                         assure qu'on ne supprime que les lignes entièrement
*                         non-informatives
* Sans cette ligne ?   Des centaines de lignes vides gonfleraient les
*                         effectifs et fausseraient les moyennes
* Décision discutable : la condition ne porte que sur Liensdeparenté,
*                         Années et Activité — pas sur Endroit. Une ligne avec
*                         Endroit renseigné mais les 3 autres à NA est conservée,
*                         alors qu'elle est peu exploitable. Inversement, une ligne
*                         avec Liensdeparenté renseigné mais Endroit manquant
*                         est également conservée — cohérent si on veut étudier
*                         le lien de parenté indépendamment de la destination.
* ----------------------------------------------------
drop if missing(Liensdeparenté) & missing(Années) & missing(Activité)

* ----------------------------------------------------
* Que fait cette ligne ?  Produit un tableau de fréquences de la variable Endroit
*                         brute (texte libre)
* Pourquoi ?              Audit visuel indispensable avant l'harmonisation :
*                         révèle la diversité des saisies (accents, abréviations,
*                         noms de villes vs pays) et permet de cibler les
*                         corrections nécessaires dans le sous-script
* Sans cette ligne ?      Aucun impact sur les données ; contrôle visuel omis,
*                         mais le sous-script serait moins bien calibré
* ----------------------------------------------------
tab Endroit

* ----------------------------------------------------
* Que fait cette ligne ?  Appelle le sous-script emigration_cleaning.do
*                         qui harmonise les destinations textuelles
* Pourquoi ?              Externalise dans un fichier dédié un traitement long
*                         et répétitif (des dizaines de replace) pour garder
*                         1. cleaning.do lisible
* Sans cette ligne ?   Endroit resterait en texte libre, inexploitable
*                         pour des analyses quantitatives
* Décision discutable : l'appel via "do" exécute le sous-script dans
*                         l'environnement courant (même données, mêmes globaux).
*                         Si le chemin ${codes} n'est pas défini, le script
*                         plante sans message d'erreur explicite sur la cause.
*                         Un "capture confirm file" préalable améliorerait
*                         la robustesse du pipeline.
* ----------------------------------------------------
do "$codes\emigration_cleaning.do"

* Compresse les types de variables pour réduire la taille du fichier
compress

* ----------------------------------------------------
* Que fait cette ligne ?  Sauvegarde la base longue des migrations nettoyées
* Pourquoi ?              Produit la livrable finale de ce bloc
* Sans cette ligne ?      Tout le travail est perdu (même bug potentiel que bloc 2)
* ----------------------------------------------------
save "${data}/emigration_cleaned.dta", replace


***===================================
*   SOUS-SCRIPT : emigration_cleaning.do
*   HARMONISATION DES DESTINATIONS
***===================================

* ----------------------------------------------------
* Que fait cette ligne ?  Convertit toute la variable Endroit en minuscules
* Pourquoi ?              Les strmatch suivants sont sensibles à la casse.
*                         Sans cette normalisation, "France" et "france"
*                         seraient deux modalités distinctes — la seconde
*                         ne serait pas capturée par strmatch(Endroit,"*france*")
* Sans cette ligne ?   Un nombre inconnu de destinations resteraient
*                         non harmonisées à cause de majuscules initiales
*                         ou de saisies en capitales
* ----------------------------------------------------
replace Endroit = lower(Endroit)

* ----------------------------------------------------
* Que fait cette ligne ?  Vide les valeurs manifestement non-informatives :
*                         "n/i" (non indiqué), "1", "18" (codes parasites),
*                         "destination inconnue"
* Pourquoi ?              Ces valeurs ne peuvent pas être catégorisées ;
*                         les laisser générerait une modalité "destination
*                         inconnue" qui serait confondue avec un lieu réel
*                         après encode
* Sans cette ligne ?   "n/i" et "destination inconnue" deviendraient des
*                         catégories de destination à part entière — absurde
* Décision discutable : "1" et "18" sont probablement des erreurs de saisie
*                         (code saisi dans la mauvaise cellule), mais leur
*                         signification originale est perdue sans archivage préalable
* ----------------------------------------------------
replace Endroit="" if Endroit=="n/i" | Endroit=="1" | Endroit=="18" | Endroit=="destination inconnue"

* ----------------------------------------------------
* Que fait cette ligne ?  Crée une copie de travail Endroit2 initialisée
*                         à la valeur courante de Endroit
* Pourquoi ?              Préserve la variable originale Endroit intacte
*                         pendant toute la phase d'harmonisation — bonne
*                         pratique qui permet de relire les valeurs brutes
*                         en cas d'erreur dans les replace suivants
* Sans cette ligne ?      On travaillerait directement sur Endroit ;
*                         toute erreur de pattern serait irréversible
* ----------------------------------------------------
gen Endroit2 = Endroit

* ----------------------------------------------------
* Que fait cette ligne ?  Liste toutes les observations où Endroit2 est vide
*                         après la mise à "" des valeurs non-informatives
* Pourquoi ?              Audit intermédiaire : vérifie combien de destinations
*                         sont déjà perdues avant même l'harmonisation,
*                         et lesquelles (utile pour décider si on peut les
*                         récupérer via d'autres variables du ménage)
* Sans cette ligne ?      Aucun impact sur les données ; contrôle visuel omis
* ----------------------------------------------------
list if Endroit2==""

* (désactivée) Aurait supprimé les observations avec plusieurs champs manquants
* — logique similaire au drop if du script principal, mais non finalisée
//drop if missing() & missing() & missing()

* ==================
*  Affectation des destinations par zone géographique
*  Principe : strmatch(Endroit, "*pattern*") capture toute valeur
*  contenant le pattern, quelle que soit sa position dans la chaîne
* ==================

* ----------------------------------------------------
* Que fait cette ligne ?  Affecte "Afrique Centrale" à toute destination
*                         contenant "congo" ou "gabon"
* Pourquoi ?              Ces pays correspondent à des flux migratoires
*                         connus des pastoraux sahéliens (travail saisonnier,
*                         commerce de bétail vers les zones forestières)
* Sans cette ligne ?   "brazzaville" ou "kinshasa" resteraient en texte
*                         libre non catégorisés
* Décision discutable : "congo" capture à la fois RDC et République du Congo
*                         — deux destinations très différentes en termes
*                         de distance et de type de migration, mais regroupées
*                         dans la même zone
* ----------------------------------------------------
replace Endroit2="Afrique Centrale" if strmatch(Endroit, "*congo*") | strmatch(Endroit, "*gabon*")

* ----------------------------------------------------
* Que fait cette ligne ?  Affecte "Europe-US" aux destinations européennes
*                         et nord-américaines
* Décision discutable : "*esp*" capture "espagne" mais aussi tout mot
*                         contenant "esp" (ex. "espoir", un nom de lieu fictif).
*                         Les patterns courts et ambigus sont risqués avec strmatch.
*                         De même, regrouper Europe et USA dans une seule zone
*                         efface des distinctions analytiques importantes
*                         (migration économique en France ≠ migration en Espagne).
* ----------------------------------------------------
replace Endroit2="Europe-US" if strmatch(Endroit, "*belg*") | strmatch(Endroit, "*esp*") ///
    | strmatch(Endroit, "*france*") | strmatch(Endroit, "usa") | strmatch(Endroit, "etats-unis")

* ----------------------------------------------------
* Que fait cette ligne ?  Affecte "Afrique du Nord" aux destinations maghrébines
*                         et péninsule arabique (Mecque incluse)
* Décision discutable : la Mecque et l'Arabie Saoudite sont classées en
*                         "Afrique du Nord" alors qu'elles se trouvent en Asie.
*                         Ce classement mélange deux types de mobilité très
*                         différents : migration économique (Algérie, Maroc)
*                         et migration religieuse (pèlerinage à la Mecque).
*                         "mecque" apparaît deux fois dans les patterns — doublon
*                         sans conséquence mais qui révèle un manque de relecture.
*                         "*lybie*" au lieu de "*liby*" suppose une orthographe
*                         spécifique — "libye" sans y ne serait pas capturée.
* ----------------------------------------------------
replace Endroit2="Afrique du Nord" if strmatch(Endroit, "*alg*") | strmatch(Endroit, "*maroc*") ///
    | strmatch(Endroit, "*arabie*") | strmatch(Endroit, "*mecque*") ///
    | strmatch(Endroit, "*lybie*") | strmatch(Endroit, "*mecque*")

* ----------------------------------------------------
* Que fait cette ligne ?  Affecte "Pays côtiers" aux pays du Golfe de Guinée
* Décision discutable : "*guin*" capture Guinée, Guinée-Bissau ET
*                         Guinée équatoriale — trois pays très différents
*                         en termes de flux migratoires. "*rci*" est une
*                         abréviation qui suppose une saisie normalisée.
*                         "bénin" apparaît trois fois (doublon sans effet
*                         mais signe de code non relu).
* ----------------------------------------------------
replace Endroit2="Pays côtiers" if strmatch(Endroit, "*benin*") | strmatch(Endroit, "*nigeria*") ///
    | strmatch(Endroit, "*rci*") | strmatch(Endroit, "*guin*") | strmatch(Endroit, "*togo*") ///
    | strmatch(Endroit, "*lome*") | strmatch(Endroit, "*ghan*") | strmatch(Endroit, "*ivoire*") ///
    | strmatch(Endroit, "*abidj*") | strmatch(Endroit, "*bénin*") | strmatch(Endroit, "*parakou*") ///
    | strmatch(Endroit, "*bénin*") | strmatch(Endroit, "*bénin*")

* ----------------------------------------------------
* Les 5 lignes suivantes affectent chaque pays sahélien de l'enquête
* à sa zone nominale. La logique est identique : patterns sur noms
* de pays + grandes villes + villes frontalières connues.
*
* Risque commun à toutes ces lignes :
*   - Les patterns sont construits à partir de la connaissance terrain
*     de l'auteur — toute ville non listée reste non catégorisée
*   - Certains patterns sont ambigus : "fada" (Burkina) existe aussi
*     sous d'autres formes dans d'autres pays ; "niger" sans wildcards
*     (strmatch(Endroit,"niger") exact) ne capturera pas "au niger"
*     ou "vers niger" si Endroit contient du texte supplémentaire
*   - "kidira" est une ville sénégalaise frontalière du Mali — la classer
*     sous "Mali" est discutable (les migrants qui y vont restent au Sénégal)
* ----------------------------------------------------

* Destinations Sénégal (liste la plus longue — pays d'enquête avec
* le plus de destinations intra-pays saisies en texte libre)
replace Endroit2="Sénégal" if strmatch(Endroit, "*senegal*") | strmatch(Endroit, "*sénég*") ///
    | strmatch(Endroit, "*touba*") | strmatch(Endroit, "*dakar*") ///
    | strmatch(Endroit, "*ndioum*") | strmatch(Endroit, "*saint-*") ///
    | strmatch(Endroit, "*kedougou*") | strmatch(Endroit, "matam") ///
    | strmatch(Endroit, "tamba*") | strmatch(Endroit, "*kaolack*") ///
    | strmatch(Endroit, "*kanel*") | strmatch(Endroit, "*dahra*") ///
    | strmatch(Endroit, "*dagana*") | strmatch(Endroit, "*casamance*") ///
    | strmatch(Endroit, "*boki*") | strmatch(Endroit, "mbafar") ///
    | strmatch(Endroit, "goléré") | strmatch(Endroit, "goudoudé") ///
    | strmatch(Endroit, "ganina")

* Destinations Mali
* "kaye*" avec wildcard final capture "kayes" mais aussi tout mot
*    commençant par "kaye" — peu risqué ici mais à vérifier
replace Endroit2="Mali" if strmatch(Endroit, "*mali*") | strmatch(Endroit, "*kaye*") ///
    | strmatch(Endroit, "*kenieba*") | strmatch(Endroit, "*djafounou*") ///
    | strmatch(Endroit, "*kidira*") | strmatch(Endroit, "koussan*")

* Destinations Burkina Faso
* "*bf*" est extrêmement court : capture tout mot contenant "bf",
*    y compris des abréviations non liées (ex. "mbfar" du Sénégal
*    pourrait être capturé si le pattern n'est pas exact)
replace Endroit2="Burkina Faso" if strmatch(Endroit, "*bf*") | strmatch(Endroit, "*burkina*") ///
    | strmatch(Endroit, "*bobo*") | strmatch(Endroit, "*ouaga*") ///
    | strmatch(Endroit, "fada") | strmatch(Endroit, "nadiabondi") ///
    | strmatch(Endroit, "solhan") | strmatch(Endroit, "saponé")

* Destinations Niger
* strmatch(Endroit, "niger") sans wildcards exige que Endroit soit
*    EXACTEMENT "niger" (après lower()) — "au niger" ou "le niger"
*    ne seraient pas capturés. Incohérence avec le style *pattern*
*    utilisé partout ailleurs.
replace Endroit2="Niger" if strmatch(Endroit, "*niamey*") | strmatch(Endroit, "niger") ///
    | strmatch(Endroit, "mokolondi")

* Destinations Mauritanie
* "*kchott*" cible "nouakchott" — le pattern suppose que la ville
*    sera toujours mal orthographiée de cette façon précise.
*    "tékane" (ville mauritanienne) est saisi avec accent — si Endroit
*    contient "tekane" sans accent, il ne sera pas capturé malgré le lower()
*    (lower() ne supprime pas les accents, seulement les majuscules)
replace Endroit2="Mauritanie" if strmatch(Endroit, "*kchott*") ///
    | strmatch(Endroit, "*al harya*") | strmatch(Endroit, "*maurit*") ///
    | strmatch(Endroit, "*sehli*") | strmatch(Endroit, "*bassikou*") ///
    | strmatch(Endroit, "*waly*") | strmatch(Endroit, "tékane")

* ----------------------------------------------------
* Que fait cette ligne ?  Remet à manquant 4 noms de lieux non identifiables
*                         qui n'ont pas été capturés par les patterns précédents
*                         et sont restés à leur valeur originale dans Endroit2
* Pourquoi ?              Ces lieux ne peuvent pas être catégorisés dans une
*                         zone géographique connue — les laisser produirait
*                         des catégories singleton non interprétables après encode
* Sans cette ligne ?   "yaféré", "sey", "marchés", "magdadouane" deviendraient
*                         des catégories de destination à part entière
* Décision discutable : ces 4 lieux pourraient être identifiables avec
*                         une recherche rapide ("magdadouane" est vraisemblablement
*                         "Maghama Daoune", une ville mauritanienne ;
*                         "yaféré" est une localité sur la frontière
*                         Sénégal-Mauritanie). Les mettre à manquant est une
*                         perte d'information évitable.
* ----------------------------------------------------
replace Endroit2="" if Endroit2=="yaféré" | Endroit2=="sey" ///
    | Endroit2=="marchés" | Endroit2=="magdadouane"

* ----------------------------------------------------
* Que fait cette ligne ?  Affiche la distribution finale de Endroit2 avec manquants
* Pourquoi ?              Contrôle de qualité final : vérifie que toutes les
*                         valeurs non-vides ont bien été catégorisées et que
*                         le taux de manquants est acceptable
* Sans cette ligne ?      Aucun impact ; audit final omis
* ----------------------------------------------------
tab Endroit2, mis

* ----------------------------------------------------
* Que font ces 2 lignes ?  Définissent les 11 labels de destination puis
*                          encodent Endroit2 (string) en variable numérique
*                          "destination" en appliquant ces labels
* Pourquoi ?              Une variable numérique est nécessaire pour les
*                         tableaux croisés, régressions et comparaisons
*                         avec la variable country (également numérique)
* Décision critique : encode assigne les codes selon l'ordre alphabétique
*                        des modalités, PAS selon l'ordre du lab def.
*                        "Afrique Centrale" (alphabétiquement premier) reçoit
*                        le code 1, pas "Sénégal". Le lab def définit les
*                        labels mais encode génère ses propres codes.
*                        Résultat : les codes numériques de "destination"
*                        ne correspondent PAS aux codes 1–5 de "country"
*                        (Sénégal=1 dans country, mais Sénégal≠1 dans destination
*                        après encode). Les replace suivants qui comparent
*                        destination==country sont donc potentiellement faux.
* ----------------------------------------------------
lab def dests 1 "Sénégal" 2 "Mali" 3 "Mauritanie" 4 "Burkina Faso" 5 "Niger" ///
    6 "Afrique Centrale" 7 "Afrique du Nord" 8 "Europe-US" ///
    9 "Pays côtiers" 10 "ailleurs dans le pays" 11 "ailleurs au Sahel"
encode Endroit2, gen(destination) label(dests)

* Tableau de contrôle de la distribution de destination après encodage
tab destination

* ----------------------------------------------------
* Que font ces 2 lignes ?  Recodent destination selon le rapport au pays d'origine :
*   - Si destination est un pays sahélien de l'enquête (code < 6)
*     ET différent du pays d'origine du ménage → "ailleurs au Sahel" (11)
*   - Si destination est un pays sahélien de l'enquête (code < 6)
*     ET identique au pays d'origine → "ailleurs dans le pays" (10)
* Pourquoi ?              Distingue la migration interne (dans le même pays)
*                         de la migration régionale sahélienne — distinction
*                         analytique fondamentale pour étudier la mobilité
*                         pastorale transfrontalière
* BUG POTENTIEL MAJEUR : cette logique suppose que les codes numériques
*                         de destination correspondent aux codes de country
*                         (1=Sénégal, 2=Mali, etc.). Or encode() assigne
*                         ses codes par ordre alphabétique de Endroit2 :
*                         "Afrique Centrale"=1, "Afrique du Nord"=2,
*                         "Burkina Faso"=3, "Europe-US"=4, "Mali"=5,
*                         "Mauritanie"=6, "Niger"=7, "Pays côtiers"=8,
*                         "Sénégal"=9. Les codes 1–5 de destination ne
*                         correspondent donc à AUCUN pays sahélien seul —
*                         la condition destination<6 sélectionne en réalité
*                         Afrique Centrale(1), Afrique du Nord(2),
*                         Burkina Faso(3), Europe-US(4), Mali(5).
*                         Et destination==country compare des codes sans
*                         commune mesure (Sénégal vaut 1 dans country
*                         mais 9 dans destination).
*                         Ce recode produit des résultats incorrects.
* ----------------------------------------------------
* Recode destination : si pays sahélien différent du pays d'enquête → "ailleurs au Sahel"
replace destination=11 if destination!=country & destination<6
* Recode destination : si même pays que le pays d'enquête → "ailleurs dans le pays"
replace destination=10 if destination==country

* ----------------------------------------------------
* Que fait cette ligne ?  Supprime les deux variables Endroit (originale
*                         et de travail Endroit2)
* Pourquoi ?              La variable destination numérique les remplace ;
*                         Endroit en texte libre est trop hétérogène pour
*                         figurer dans la base analytique finale
* Sans cette ligne ?   Endroit et Endroit2 resteraient — encombrement
* Décision discutable : supprimer Endroit (la valeur brute originale)
*                         empêche toute vérification a posteriori des
*                         catégorisations. Conserver Endroit en variable
*                         auxiliaire (ou l'exporter dans un fichier de log)
*                         aurait permis de relire les assignations.
* ----------------------------------------------------
drop Endroit*
