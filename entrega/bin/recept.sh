#!/bin/bash
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

	if [ -z "$RECEPTCOUNTER" ]; then
		echo "El contador de ciclos de recept no fue inicializado"
		exit
	fi
	
}


#chequea si hay archivos con actualizaciones para bancos, si hay los mueve a aceptados
function check_updates(){
  cantfiles=`ls -1 "$NOVEDIR" | wc -l`
  if [ $cantfiles -gt 0 ]; then
	#echo "hay $cantfiles archivos"
	IFS=$'\n'
	for f in `ls -1 "$NOVEDIR"`
	do
		echo $f
		reject_file=false
		file_type=0
		#cheuqueo si el nombre del archivo podria ser de un banco
		if [ `echo $f | grep -c "^[A-Z]*_[0-9]\{8\}$"` -gt 0 ]; then
			#echo "posiblemente sea un archivo de banco"
			check_valid_bank_file $f
			valid_bank_file=$?
			if [ $valid_bank_file -gt 0 ]; then
			    reject_file=true
			    log_rejected_file $valid_bank_file $f
			fi
			#cambio el tipo de archivo a 1 para saber que es del tipo saldos
			file_type=1
		elif [ `echo $f | grep -c "^[^@]*@[a-zA-Z\.\_0-9]*$"` -gt 0 ]; then
			#chequeo si el nombre del archivo podria ser de expedientes
			#echo "posiblemente sea un archivo de expedientes"
			check_valid_records_file $f
			check_response=$?
			if [ $check_response -gt 0 ];then
			   reject_file=true
			   log_rejected_file $check_response $f
			fi
			#cambio el tipo de archivo a 2 para saber que es un archivo de expedientes
			file_type=2
		else
		   #el archivo es invalido por su nombre
		   reject_file=true
		   log_rejected_file 9 $f
		fi
		

		if [ $reject_file == false ]; then
			#lo muevo a aceptados y logueo
			mv "$NOVEDIR/$f" "$ACEPDIR/$f"
			if [ $file_type -eq 1 ]; then
				log_data "Archivo de Saldos aceptado: $f"
			elif [ $file_type -eq 2 ]; then
				log_data "Archivo de Expedientes aceptado: $f"
			fi
		else
			#lo muevo a la carpeta de rechazados
			mv "$NOVEDIR/$f" "$RECHDIR/$f"
		fi	
	done 
  else
	log_data "No hay archivos de novedades"
  fi 
}


############################## FUNCIONES PARA VALIDAR ARCHIVOS DE BANCOS #####################################################

function check_valid_bank_file(){
  #chequeo si es un archivo de texto
  is_a_valid_file $1
  bank_valid_file=$?
  if [ $bank_valid_file -gt 0 ]; then
	return $bank_valid_file	
  fi

  #chequeo si el banco existe en el archivo maestro
  bank=`echo $1 | sed 's-^\([A-Z]*\)_[0-9]*$-\1-'`
  bank_exists_in_master=`grep -wc "$bank" "$MAEDIR/bancos.dat"`
  if [ $bank_exists_in_master -eq 0 ]; then
  	return 5
  fi
  #chequeo la fecha del archivo  
  fileDate=`echo $1 | sed 's-^[A-Z]*_\([0-9]*\)$-\1-'`	
  #echo $fileDate
  check_bank_file_date $fileDate
  return $?
}


#chequea que la fecha del archivo de novedades este entre
#un mes atras y hoy
function check_bank_file_date(){
  date "+%Y%m%d" -d "$1" 2>1 > /dev/null
  dateResult=$?
  if [ ! $dateResult -eq 0 ]; then
 	#echo -e "fecha invalida\n"
  	return 6
  fi 
  #chequeo el rango de las fechas
  
  #obtengo el timestamp de la fecha de hoy
  dateNow=`date "+%Y%m%d"`
  dateNow=`date --date="$dateNow" "+%s"`
  
  fileDate=`date --date="$1" "+%s"`
  if [ $fileDate -gt $dateNow ]; then
	#echo -e "fecha de archivo mayor a ahora\n"
	return 7
  fi
 
  dateAMonthAgo=`expr $dateNow - \( 30 \* 24 \* 60 \* 60 \)`   
  #echo -e "fecha hace un mes $dateAMonthAgo\n"
  
  if [ $fileDate -lt $dateAMonthAgo ]; then
	#echo "fecha del archivo demasiado vieja"
	return 8
  else
	#echo "la fecha esta bien"
 	return 0
  fi
}


#chequea que el archivo sea de texto
function is_a_valid_file(){
   #echo "archivo actual: $1"
   fileType=`file "$NOVEDIR/$1" | sed 's-[^\:]*\:\(.*\)$-\1-'`
   # echo "tipo del archivo $fileType"
   
   #chequeo si es un archivo de texto
   echo $fileType | grep -qi "ascii text"
   
   if [ $? -eq 0 ];  then
	#echo "es un archivo de ascii texto"
	return 0
   fi

   echo $fileType | grep -qi "ISO-8859 text"
    if [ $? -eq 0 ];  then
	#echo "es un archivo de iso texto"
	return 0
   fi


   #chequeo si es un archivo vacio
   echo $fileType | grep -q "empty"
   if [ $? == 0 ]; then
	#echo "el archivo esta vacio"
	return 2
   fi

   #es de cualquier otro tipo
   #echo "el tipo del archivo es invalido ($fileType )"
   return 1
}

############################## !FUNCIONES PARA VALIDAR ARCHIVOS DE BANCOS #####################################################




############################# FUNCIONES PARA VALIDAR ARCHIVOS DE EXPEDIENTES ##################################################

function check_valid_records_file(){
    # chequeo que el archivo sea valido
    is_a_valid_file $f
    response_valid_file=$?
    if [ $response_valid_file -gt 0 ]; then
	return $response_valid_file
    fi

    ## chequeo que la camara exista en el maestro de camaras
    chamber=`echo $1 | sed 's-^\([^@]*\)@[a-zA-Z\.\_0-9]*$-\1-'`
    #echo "camara $chamber"
    if [ `grep -wc $chamber "$MAEDIR/camaras.dat"` -eq 0 ]; then
	#echo  "la camara no existe"
    	return 3
    fi
    ## chequeo que el tribunal exista en el maestro
    court=`echo $1 | sed 's-^[^@]*@\([a-zA-Z\.\_0-9]*\)$-\1-'`
    echo $court
    if [ `grep -wc $court "$MAEDIR/pjn.dat"` -eq 0 ]; then
	#echo "el tribunal no existe"
	return 4
    fi

    return 0
}


############################# !FUNCIONES PARA VALIDAR ARCHIVOS DE EXPEDIENTES ##################################################

#logea el tipo de error del archivo en logs
# primer parametro: error_code
# segundo parametro: nombre del archivo
function log_rejected_file(){
	reason=""
	case "$1" in 
		1) reason="Tipo de archivo invalido." ;;
		
		2) reason="Archivo vacio." ;;

		3) reason="Cámara inexistente." ;;
		
		4) reason="Tribunal inexistente." ;;
	
		5) reason="Entidad inexistente." ;;

		6) reason="Fecha invalida." ;;
	
		7) reason="La fecha del archivo es mayor a hoy." ;;

		8) reason="La fecha del archivo es muy vieja." ;;

		9) reason="El nombre del archivo es invalido" ;; 
	esac  
	
	log_data "Archivo Rechazado: $2. Motivo: $reason"
}



#loguea informacion
function log_data(){
	echo -e  $1 >> "$LOGDIR/recept.log"
}


######################## FIN FUNCIONES #############################

check_environment


process_pid=0
process_running=0
while true ; do
#cambio la variable recept counter y logueo ciclo
current_cycle=`expr $RECEPTCOUNTER + 1`
export RECEPTCOUNTER=$current_cycle
log_date=`date "+%d/%m/%Y %H:%m:%S"`
log_data "\n==================== RECEPT: CICLO $RECEPTCOUNTER ====================\n\nFecha: $log_date\n\n" 

#chequeo si hay archivos de bancos o de expedientes para actualizar
log_data "CHEQUEO DE NOVEDADES:\n"
check_updates
log_data "\n\n"

log_data "PROCESOS:\n"
#echo $process_pid
#si hay archivos de bancos aceptados y no hay procesos corriendo corro fsoldes
if [ `ls -1 "$ACEPDIR" | grep -c "^[A-Z]*_[0-9]\{8\}$"` -gt 0 ]; then
	#echo "hay archivos de bancos"
	#echo `ps -p $process_pid`
	if [ $process_pid -gt 0 ]; then
	   	process_running=`ps -p "$process_pid" | grep -wc "$process_pid"`
	fi
	
	#echo $process_running
	if [ $process_pid -eq 0 ] || [ $process_running -eq 0 ]; then
		#echo "no hay procesos corriendo"
		#corro fsoldes
		./mock_fsoldes.sh &
		process_pid=$!
		log_data "FSOLDES corriendo bajo el número: $process_pid\n"
	else	
		#echo "hay un proceso corriendo"
		log_data "Invocacion de FSOLDES pospuesta para el siguiente ciclo\n" 
	fi	
else
	log_data "No hay archivos de bancos para procesar\n"

fi

#si hay archivos de expedientes aceptados y no hay procesos corriendo ejecuto cdossier
if [ `ls -1 "$ACEPDIR" | grep -c "^[^@]*@[a-zA-Z\.\_0-9]*$"` -gt 0 ]; then
	#echo "hay archivos de juzgados"
	#echo `ps -p $process_pid`
	if [ $process_pid -gt 0 ]; then
	   	process_running=`ps -p "$process_pid" | grep -wc "$process_pid"`
	fi
	
	#echo $process_running
	if [ $process_pid -eq 0 ] || [ $process_running -eq 0 ]; then
		#echo "no hay procesos corriendo"
		#corro cdossier
		./mock_cdossier.sh &
		process_pid=$!
		log_data "CDOSSIER corriendo bajo el número: $process_pid\n"
	else	
		#echo "hay un proceso corriendo"
		log_data "Invocacion de CDOSSIER pospuesta para el siguiente ciclo\n" 
	fi	
else
	log_data "No hay archivos de juzgados para procesar\n"

fi



log_data "\n\n"
sleep 10
done