#funcion para chequear que fue inicializado el ambiente
function check_environment(){

	#chequeo directorio maestro
	if [ -z "$MAEDIR" ] || [ ! -d "$MAEDIR" ]; then
		echo "El directorio Maestro no fue iniciazizado"
		exit
	fi
	
  	if [ -z "$NOVEDIR" ] || [ ! -d "$NOVEDIR" ]; then
		echo "El directorio Novedades no fue iniciazizado"
		exit
	fi

	if [ -z "$ACEPDIR" ] || [ ! -d "$ACEPDIR" ]; then
		echo "El directorio Aceptados no fue iniciazizado"
		exit
	fi

	if [ -z "$RECHDIR" ] || [ ! -d "$RECHDIR" ]; then
		echo "El directorio Rechazados no fue iniciazizado"
		exit
	fi

	if [ -z "$LOGDIR" ] || [ ! -d "$LOGDIR" ]; then
		echo "El directorio de Logs no fue iniciazizado"
		exit
	fi
	
}


#chequea si hay archivos con actualizaciones para bancos, si hay los mueve a aceptados
function check_bank_updates(){
  cantfiles=`ls "$NOVEDIR" | grep -c '^[A-Z]*_[0-9]\{8\}$'`
  if [ $cantfiles -gt 0 ]; then
	echo "hay $cantfiles archivos"
	for f in `ls "$NOVEDIR" | grep '^[A-Z]*_[0-9]\{8\}$'`
	do
		check_valid_bank_file $f
		valid_bank=$?
		#if [ $valid_bank -eq 0 ]; then
		#	echo "es valido"
		#else
		 #	echo "es invalido"
		#fi
	done 
  else
	echo "no hay archivos"
  fi 
}

function check_valid_bank_file(){
  #chequeo si el banco existe en el archivo maestro
  bank=`echo $1 | sed 's-^\([A-Z]*\)_[0-9]*$-\1-'`
  result=`grep "$bank" "$MAEDIR/bancos.dat"`
  #if [ "$result" = "" ]; then
  #	return 1
  #fi
  #chequeo la fecha del archivo  
  fileDate=`echo $1 | sed 's-^[A-Z]*_\([0-9]*\)$-\1-'`	
  #echo $fileDate
  #check_bank_file_date $fileDate
  is_a_valid_file $1
}


#chequea que la fecha del archivo de novedades este entre
#un mes atras y hoy
function check_bank_file_date(){
  date "+%Y%m%d" -d "$1" 2>1 > /dev/null
  dateResult=$?
  if [ ! $dateResult -eq 0 ]; then
 	echo -e "fecha invalida\n"
  	return 1
  fi 
  #chequeo el rango de las fechas
  
  #obtengo el timestamp de la fecha de hoy
  dateNow=`date "+%Y%m%d"`
  dateNow=`date --date="$dateNow" "+%s"`
  
  fileDate=`date --date="$1" "+%s"
`
  if [ $fileDate -gt $dateNow ]; then
	echo -e "fecha de archivo mayor a ahora\n"
	return 1
  fi
 
  dateAMonthAgo=`expr $dateNow - \( 30 \* 24 \* 60 \* 60 \)`   
  #echo -e "fecha hace un mes $dateAMonthAgo\n"
  
  if [ $fileDate -lt $dateAMonthAgo ]; then
	echo "fecha del archivo demasiado vieja"
	return 1
  else
	echo "la fecha esta bien"
 	return 0
  fi
}


#chequea que el archivo sea de texto
is_a_valid_file(){
   echo "archivo actual: $1"
   fileType=`file "$NOVEDIR/$1"`
   echo "tipo del archivo $fileType"
}



#loguea informacion
function log_data(){
	echo $1 >> "$LOGDIR/recept.log"
}

check_environment

#cheuqeo si hay archivos de bancos para actualizar
check_bank_updates
