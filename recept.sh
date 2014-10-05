#funcion para chequear que fue inicializado el ambiente
check_environment(){

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
check_bank_updates(){
  cantfiles=`ls "$NOVEDIR" | grep -c '^[A-Z]*_[0-9]\{8\}$'`
  if [ $cantfiles -gt 0 ]; then
	echo "hay $cantfiles archivos"
	for f in `ls "$NOVEDIR" | grep '^[A-Z]*_[0-9]\{8\}$'`
	do
		check_valid_bank_file
	done 
  else
	echo "no hay archivos"
  fi 
}

check_valid_bank_file(){
  bank=`echo $1 | sed "s/^([A-Z]*)_[0-9]*/\1/"` 
  echo "banco $bank"
}


#loguea informacion
log_data(){
	echo $1 >> "$LOGDIR/recept.log"
}

check_environment

#cheuqeo si hay archivos de bancos para actualizar
check_bank_updates
