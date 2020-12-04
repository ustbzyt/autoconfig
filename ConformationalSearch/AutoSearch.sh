#!/bin/bash

# Check the number of xyz files in current directory
count_xyz_gjf(){
num_xyz=`ls -1 *.xyz | wc -l`
if [[ -e template.gjf && $num_xyz == 1 ]]
then 
	echo "Both the temple.gjf file and ONE xyz file are found. Good to continue..."
else
	echo "Error: please provide the temple.gjf file and ONE xyz file..."
	exit $?
fi
}

# Get the charge state from the input file name
chkchrg(){
echo "
*************************************************************
Checking the charge state based on the input file name..."
Ani="Ani"
Neu="Neu"
Cat="Cat"
if [[ $1 == *"$Ani"* ]]
then
	echo "Result: it is an ANION"
	chrg="-1"
elif [[ $1 == *"$Neu"* ]]
then
	echo "Result: it is NEUTRAL"
	chrg="0"
elif [[ $1 == *"$Cat"* ]]
then
	echo "Result: it is a CATION"*
	chrg="+1"
else
	echo "Error: the charge state is not specified in the input file name..."
	echo "Please include Ani, Neu or Cat in your input file name..."
	exit
fi
echo "*************************************************************
Starting conformational searches...
"
}

# Does one single run and checks the new best
search(){
echo "
Time: $(date '+%Y-%m-%d %H:%M')"
currenttime=$(date +%Y%m%d%H%M)
echo "Making directory ${currenttime}
Running conformational search..."
mkdir ${currenttime}
mv $1 ${currenttime}
cd  ${currenttime}
output=$(echo "${inputname}_${currenttime}_crest_output.txt")
crest $1 -nozs -chrg $chrg >> $output
echo "Conformational search completed.
Comparing the new best with the previous one..."
groupname=$(echo "${inputname}_${currenttime}_ensemble.xyz")
cp crest_conformers.xyz ../Sum/$groupname
new_energy=$(cat crest_best.xyz | head -2 | tail -1)
energy_diff=$(echo $(bc <<< "$energy-$new_energy"))
if (( $(echo "$energy_diff > 0.00001" | bc -l) ))
then
	echo "A better conformation is found.
Energy of the new best is : ${new_energy} a.u. 
Running conformational search with the new best..."
	energy=$new_energy
	i=1
	bestname=$(echo "${inputname}_BstFrm_${currenttime}.xyz")
	cp crest_best.xyz ../$bestname
	cd ..
	inputfile=$bestname
else
	echo "The best conformation from previous run is still the best."	
	energy=$new_energy
	bestname=$(echo "${inputname}_BstFrm_${currenttime}.xyz")
	cp crest_best.xyz ../$bestname
	cd ..
	inputfile=$bestname
fi
}

# Screening of the ensembles 
rescreen(){
echo "
Time: $(date '+%Y-%m-%d %H:%M')
Screening the generated conformations..."
cd Sum
sumname=$(echo "${inputname}_Sum.xyz")
output=$(echo "${inputname}_Sum_ReScreen_output.txt")
cat *.xyz > $sumname
mkdir ReScreen
cp $sumname ReScreen
cd ReScreen
crest -screen $sumname -nozs -chrg $chrg >> $output
echo "Conformational search and screen completed"
echo "******************************************************************"
mkdir ../../../HF321GD
cp crest_ensemble.xyz ../../../HF321GD
}

# The main body starts here
echo "
       =================================================================
       |                                                               |
       |   Auto Conformational Search Script using crest (autosearch)  |
       |                  Yuntao Zhang, 2020/11/08                     |
       |                                                               |
       =================================================================
	   ATTN: crest, xtb, and molclus will be called to do the job.
	   
	   "
# Get the current workding directory	   
location=$(pwd)

# Make sure the template.gjf and an input xyz file are available.
count_xyz_gjf

# Part One: conformational search
inputfile=$(basename ./*.xyz)
inputname=$(echo "$inputfile" | cut -f 1 -d '.')
# Make necessary directories for the conformer search
mkdir -p HF321GD crest_search/Sum 
cp $inputfile crest_search
cd crest_search
energy=0
chkchrg "$inputfile"
for (( i=1; i<=3; i++ ))
do
	search "$inputfile"
	if (( i == 2 ))
	then
		echo "Running one more round of search with the same best..."
	elif (( i == 3 ))
	then
		echo "The last round of conformational search is completed"
	fi
done

if [ -f ./*.xyz ]
then
	rm *.xyz
fi
rescreen

if [ -f ./*.gif ]
then
	inputfile=$(basename ./*.xyz)
	cp $inputfile HF321GD
	cd HF321GD
	Multiwfn ${inf} << EOF > /dev/null
100
2
2
${inf//gjf/xyz}
0
q
EOF
