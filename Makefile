-include ../etc/Makefile

D=auto2 auto93 nasa93dem china coc1000 healthCloseIsses12mths0011-easy \
   healthCloseIsses12mths0001-hard pom SSN SSM#
nbs: ## DEMO. checks  if best breaks are at root of tree (level=1) or other
	$(foreach d,$D, lua treego.lua -f $R/data/$d.csv -g nbs; )

README.md: ../readme/readme.lua incb.lua ## update readme
	printf "\n# INBC\n Incremental Naive Bayes classifier\n" > README.md
	printf "<img src=bayes.net width=250 align=right>" >> README.md
	lua $< incb.lua >> README.md

myInstall: $R/readme $R/data $R/glua

$R/glua:;   cd $R; git clone https://github.com/timm/glua
$R/readme:; cd $R; git clone https://github.com/timm/readme
$R/data  :; cd $R; git clone https://github.com/timm/data
