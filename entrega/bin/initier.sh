#!/bin/bash

#HAY QUE CORRER EL PROGRAMA ASÍ: 'source initializer.sh', de manera que los exports perduren en la sesión.

export grupo=..
export CONF_FILE=$grupo/conf/Deployer.conf
#export CONF_FILE=../conf/Deployer.conf

log(){
	./logging.sh initier $1 $2
}

initializeEnvironment(){
	echo "Inicializando el ambiente\n"
	export INITIALIZED=1
	echo "TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo $grupo"
	echo -e "Directorio Configuracion: $grupo/conf \nContenido:"
	showFiles $grupo/conf
	echo -e "Directorio Ejecutables: BINDIR $BINDIR \nContenido:"
	showFiles $BINDIR
	echo -e "Directorio Datos Maestros y Tablas: $MAEDIR \nContenido:"
	showFiles $MAEDIR
	echo "Directorio Flujo de Novedades: $NOVEDIR"
	echo "Directorio Novedades Aceptadas: $ACEPDIR"
	echo "Directorio Pedidos e Informes de Salida: $REPODIR"
	echo "Directorio Archivos Rechazados: $RECHDIR"
	echo "Directorio de Logs de Comandos: $LOGDIR"
	echo "SubDirectorio de Resguardo de Archivos Duplicados: $DUPDIR"
	echo "Estado del Sistema: INICIALIZADO"
}

checkEnvironment(){
	if [ "$INITIALIZED" == 1 ]
	then
		echo -e "Ambiente ya inicializado. Si quiere reiniciar, termine su sesión e ingrese nuevamente\n"
	fi
}

#$1: Archivo a verificar
checkFileExists(){
	if [ ! -e "$1" ]
	then	
		CORRECT_INSTALL=0
		echo -e "No se encuentra el archivo $1"
		log "No se encuentra el archivo $1" ERR
	fi
}

showFiles()
{
	for curFile in $1/*
	do
		echo "$curFile"
	done
}

loadConfig(){
	if [ -f "$CONF_FILE" ]
	then
		export MAEDIR=`grep ^MAEDIR $grupo/conf/Deployer.conf | sed s/MAEDIR=//g | sed s/=.*//`
		export CONFDIR=`grep ^CONFDIR $grupo/conf/Deployer.conf | sed s/CONFDIR=//g | sed s/=.*//`
		export BINDIR=`grep ^BINDIR $grupo/conf/Deployer.conf | sed s/BINDIR=//g | sed s/=.*//`
		export NOVEDIR=`grep ^NOVEDIR $grupo/conf/Deployer.conf | sed s/NOVEDIR=//g | sed s/=.*//`
		export ACEPDIR=`grep ^ACEPDIR $grupo/conf/Deployer.conf | sed s/ACEPDIR=//g | sed s/=.*//`
		export REPODIR=`grep ^REPODIR $grupo/conf/Deployer.conf | sed s/REPODIR=//g | sed s/=.*//`
		export RECHDIR=`grep ^RECHDIR $grupo/conf/Deployer.conf | sed s/RECHDIR=//g | sed s/=.*//`
		export LOGDIR=`grep ^LOGDIR $grupo/conf/Deployer.conf | sed s/LOGDIR=//g | sed s/=.*//`
		export DUPDIR=`grep ^DUPDIR $grupo/conf/Deployer.conf | sed s/DUPDIR=//g | sed s/=.*//`
		CONFIG_LOADED=0
	else
		echo -e "No se encuentra el archivo de configuración, verifique que la instalación se haya efectuado correctamente\n"
		echo "Error: No se encuentra $CONF_FILE"
		CONFIG_LOADED=1
	fi
}

checkPermissions(){
	chmod 700 $1
	PERMISSION_OK=`stat -c %a $1 | sed s/[6,7][0-7][0-7]/0/`
	if [ "$PERMISSION_OK" != 0 ]
	then
		log "No se pudieron setear los permisos correctos de $1"
		CHECK_PERMISSIONS_FAILED=0
	fi
}

initializeReceipt(){
	echo "¿Desea efectuar la activación del Receipt?"
	select ACTION in SI NO;
	do
		case $ACTION in
		"SI")
			./debut.sh recept.sh
		#RECEIPT_PROC=`pgrep debut.sh`
		#if [ "$RECEIPT_PROC" == "" ]
		#then
		#	echo "Se activará el script de receipt."
		#	./debut.sh recept.sh
		#else
			#echo "El demonio de Receipt ya se encuentra corriendo."
		#fi
		break
		;;
		"NO")
		echo "Para arrancar el Receipt, por favor seguir los siguientes pasos"
		echo "Ejecutar ./debut.sh recept.sh"
		echo "Apretar enter"
		break
		;;
		*)
		echo "Elegiste $ACTION"
		echo "Opción incorrecta, por favor elija  1 para 'SI' o 2 para 'NO'"
		;;
		esac
	done
}

########
# Main #
########

checkEnvironment
if [ -z "$INITIALIZED" ]
then
loadConfig
	if [ "$CONFIG_LOADED" == 0 ] # Cargó las configuraciones
	then
		checkFileExists $MAEDIR
		checkFileExists $BINDIR
		checkFileExists $MAEDIR/bancos.dat
		checkFileExists $MAEDIR/camaras.dat
		checkFileExists $MAEDIR/pjn.dat
		if [ "$CORRECT_INSTALL" == 0 ]
		then
			echo -e "La instalación no se realizó correctamente"
			exit
		fi
		checkPermissions $MAEDIR/bancos.dat
		checkPermissions $MAEDIR/camaras.dat
		checkPermissions $MAEDIR/pjn.dat
		checkPermissions $BINDIR/*.sh
		if [ "$CHECK_PERMISSIONS_FAILED" == 0 ]
		then
			echo -e "La instalación no se realizó correctamente, no se pueden cambiar los permisos"
			exit
		fi
		initializeEnvironment
	fi
	initializeReceipt
fi

