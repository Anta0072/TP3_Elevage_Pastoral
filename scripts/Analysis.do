global root      "C:\Users\ndaoa\Documents\ISEP2\Statistiques agricoles\TP3"  // ← changer ici

* Les chemins suivants se construisent automatiquement — NE PAS MODIFIER
global inputfile "$root\data\cleaned\FT_cleanMenage.dta"      // données brutes (.dta)
global data      "$root\data\cleaned"  // données nettoyées
global codes     "$root\scripts"       // scripts .do
global output    "$root\Outputs"

*On charge la base
use "${inputfile}", clear  

// Subsistance du ménage
*1. La proportion de familles pratiquant l'agriculture en plus de l'élevage
replace AGRICULTURE = "Oui" if Mil == "Oui"
*Vous verrez l'explication dans la question suivante
bysort country: tab AGRICULTURE, mis
tab AGRICULTURE, mis
// Sénégal : 60%, Mali : 57,14%, Mauritanie : 62,86%, Burkina Faso : 100%, Niger : 95,71%

*2. La proportion pour les différentes cultures
*On nettoie les colonnes et affiche les tableaux de fréquence, on remarque que le nombre de ménages pratiquant l'agriculture en plus de l'élevage est de 279 tandis que le total des tableaux sortis est de 280 pour les cultures différentes de Autres. En regardant la base, on voit qu'il y a un ménage qui a la modalité Non pour la variable AGRICULTURE et des modalités Oui pour les variables telles que Maïs, Sorgho, etc. Il faut donc inclure ce ménage parmi ceux qui pratiquent l'agriculture
codebook Mil
foreach var of varlist Mil Sorgho Maïs Niébé Manioc Arachide Coton Culturesmaraîchères Autres {
	replace `var'="Oui" if `var'=="`var'"
	tab country `var', row
}
// Mil : 64,64 % des ménages Sorgho : 64,64% Maïs : 60,71% Niébé : 70,36% Manioc : 4,29 Arachide : 45% Coton : 0,36 Culturesmaraîchères : 11,08%

*3. La taille du ménage en Équivalents adultes (EA)
bysort country : egen HHEAsize = mean(HHsizeEA)
preserve
duplicates drop country HHEAsize, force
list country HHEAsize
restore

*4. Le nombre de mois d'autosuffisance de la production agricoles
bysort country : egen autosuff = mean(Nbremoisautosuffis)
preserve
duplicates drop country autosuff, force
list country autosuff
restore

*5. La taille du cheptel en Unités de bétail tropical (UBT)
gen animal_UBT = 0.7 * transh_Bovins + transh_Camelins + 0.1 * transh_Caprins + 0.1 * transh_Ovins
bysort country : egen taille_UBT = mean(animal_UBT)
preserve
duplicates drop country taille_UBT, force
list country taille_UBT
restore

*6. L'indicateur de viabilité de l'élevage (UBT/EA)
gen via_el = taille_UBT/HHEAsize
preserve
duplicates drop country via_el, force
list country via_el
restore

compress
save "${data}\FT_cleanMenage_Analysed.dta"

*==============================================================
*			Ventes de bétails durant la transhumance
*==============================================================
use "${data}\vente_betail_cleaned.dta", clear

*1. Générer un tableau présentant pour chaque pays : le nombre d'observations, la moyenne, la médiane, l'écart-type, le minimum et le maximum des prix de vente.
tabstat Prix, by(country) s(n mean p50 sd min max)

*2. Générer un graphique du prix de vente médian par sexe et par pays. La nature exacte du graphique est à votre discrétion — justifiez votre choix.
bysort country Sexe : egen med_prix = median(Prix)
graph bar med_prix, over(Sexe, label(angle(45))) over(country) ///
	ytitle("Prix médian par sexe et par pays")
	graph export "${output}\graphique_Prix_vente_median.png"

*3. À travers une régression linéaire, modéliser le prix de vente en fonction du sexe, de l'âge, de l'origine, du type de client, de la période de vente et du pays. Interpréter les coefficients
destring Année, replace
reg Prix Sexe Age Origine Aqui Mois Année country

*4. Proposer et justifier d'autres variables qui pourraient être pertinentes pour ce modèle.


*=================================================================
*	    				Elevage et émigration
*=================================================================
use "${data}\emigration_cleaned.dta", clear

*1. Pour chaque ménage, calculer le nombre de personnes ayant émigré durant les 5 années précédant l'enquête
gen ind_migr = migr_number if Année >= 5
bysort ID : egen sum_migr = sum(ind_migr)
drop ind_migr
preserve
duplicates drop ID sum_migr, force
list ID sum_migr
restore

*2. Calculer l'intensité de l'émigration en rapportant le nombre d'émigrés à la taille du ménage. Résumer ce taux par pays
merge m:1 ID using "${data}\FT_cleanMenage_Analysed.dta"
bysort ID : egen migr = sum(migr_number)
bysort ID : gen intensité = migr/HHsize
bysort country : egen intens_country = mean(intensité)
preserve
duplicates drop country intens_country, force
list country intens_country
restore

*3. Quelles sont les principales destinations des fils d'éleveurs du Sahel?
tab Liensdeparenté
preserve
keep if Liensdeparenté == "Fils"
graph bar (count), over(destination, label(angle(45))) ///
	ytitle("Destination des fils d'éleveurs du Sahel")
	graph export "${output}\Principales destinations.png"
restore

*4. Quelles sont les destinations principales des émigrés?
graph bar (count), over(destination, label(angle(45)))

*5. Corréler l'intensité de l'émigration avec l'indicateur de viabilité de l'élevage. Conclure
correlate intens_country via_el
pwcorr intens_country via_el, sig
* Pas de relation statistiquement significative entre les deux variables