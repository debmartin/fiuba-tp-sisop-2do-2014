#!/bin/bash

#HAY QUE CORRER EL PROGRAMA ASÍ: 'source initializer.sh', de manera que los exports perduren en la sesión.

export grupo=07

log(){
	echo -e "[$2] - $1"
}

initializeEnvironment(){
	echo "Inicializando el ambiente\n"
	export INITIALIZED=1
	echo "TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo $grupo"
	echo -e "Directorio Configuracion: $grupo/conf \nContenido:"
	showFiles $grupo/conf
	echo -e "Directorio Ejecutables: BINDIR $PATH_BINDIR \nContenido:"
	showFiles $PATH_BINDIR
	echo -e "Directorio Datos Maestros y Tablas: $PATH_MAEDIR \nContenido:"
	showFiles $PATH_MAEDIR
	echo "Directorio Flujo de Novedades: $PATH_NOVEDIR"
	echo "Directorio Novedades Aceptadas: $PATH_ACEPDIR"
	echo "Directorio Pedidos e Informes de Salida: $PATH_REPODIR"
	echo "Directorio Archivos Rechazados: $PATH_RECHDIR"
	echo "Directorio de Logs de Comandos: $PATH_LOGDIR"
	echo "SubDirectorio de Resguardo de Archivos Duplicados: $PATH_DUPDIR"
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
	if [ ! -e $1 ]
	then	
		CORRECT_INSTALL=0
		echo -e "No se encuentra el archivo $1"
		log "No se encuentra el archivo $1" "ERR"
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
	if [ -f $grupo/conf/Deployer.conf ]
	then
		export PATH_MAEDIR=`grep ^MAEDIR $grupo/conf/Deployer.conf | sed s/MAEDIR=//g`
		export PATH_BINDIR=`grep ^BINDIR $grupo/conf/Deployer.conf | sed s/BINDIR=//g`
		export PATH_NOVEDIR=`grep ^NOVEDIR $grupo/conf/Deployer.conf | sed s/NOVEDIR=//g`
		export PATH_ACEPDIR=`grep ^ACEPDIR $grupo/conf/Deployer.conf | sed s/ACEPDIR=//g`
		export PATH_REPODIR=`grep ^REPODIR $grupo/conf/Deployer.conf | sed s/REPODIR=//g`
		export PATH_RECHDIR=`grep ^RECHDIR $grupo/conf/Deployer.conf | sed s/RECHDIR=//g`
		export PATH_LOGDIR=`grep ^LOGDIR $grupo/conf/Deployer.conf | sed s/LOGDIR=//g`
		export PATH_DUPDIR=`grep ^DUPDIR $grupo/conf/Deployer.conf | sed s/DUPDIR=//g`
		CONFIG_LOADED=0
	else
		echo -e "No se encuentra el archivo de configuración, verifique que la instalación se haya efectuado correctamente\n"
		log "No se encuentra $grupo/conf/Deployer.conf" "ERR"
		CONFIG_LOADED=1
	fi
}

checkPermissions(){
	chmod +600 $1
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
		RECEIPT_PROC=`pgrep -f vi`
		if [ "$RECEIPT_PROC" == "" ]
			echo "Se activará el script de receipt."
			./receipt.sh
		else
			echo "El demonio de Receipt ya se encuentra corriendo."
		fi
		break
		;;
		"NO")
		echo -e "Para arrancar el Receipt, por favor seguir los siguientes pasos...\n"
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
loadConfig
if [ "$CONFIG_LOADED" == 0 ] # Cargó las configuraciones
then
	checkFileExists $PATH_MAEDIR
	checkFileExists $PATH_BINDIR
	checkFileExists $PATH_MAEDIR/bancos.dat
	checkFileExists $PATH_MAEDIR/camaras.dat
	checkFileExists $PATH_MAEDIR/pjn.dat
	if [ "$CORRECT_INSTALL" == 0 ]
	then
		echo -e "La instalación no se realizó correctamente"
		exit
	fi
	checkPermissions $PATH_MAEDIR/bancos.dat
	checkPermissions $PATH_MAEDIR/camaras.dat
	checkPermissions $PATH_MAEDIR/pjn.dat
	if [ "$CHECK_PERMISSIONS_FAILED" == 0 ]
	then
		echo -e "La instalación no se realizó correctamente, no se pueden cambiar los permisos"
		exit
	fi
	initializeEnvironment
fi
initializeReceipt
