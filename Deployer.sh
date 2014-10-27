#!/bin/bash

GRUPO="$(cd "$(dirname "../../")" && pwd)"
INSTALADOR="instalador"
CONFDIR="conf"
ARCHLOG="$CONFDIR/Deployer.log"
ARCHCONF="$CONFDIR/Deployer.conf"
BINDIR="bin"
MAEDIR="data"
NOVEDIR="flux"
DATASIZE="100"
ACEPDIR="ok"
REPODIR="demande"
RECHDIR="nok"
LOGDIR="log"
DUPDIR="dup"

DIRECTORIOS=( CONFDIR BINDIR MAEDIR NOVEDIR ACEPDIR REPODIR RECHDIR LOGDIR DUPDIR )



salir() {
	#cerrar el archivo log
	exit 0
}

chequear_salida() {
	if [ $? -ne 0 ]; then
		salir
	fi
}

grabar_log() {
	DONDE_GRABA="$1"
	QUE_GRABA="$2"
	MSJ="$3"
	FECHA=$(date +"%d/%m/%Y-%H:%M:%S")
	echo -e "$FECHA-$USER-$DONDE_GRABA-$QUE_GRABA-$MSJ" >> "../$ARCHLOG"
}

mostrar_y_grabar() {
	echo -e "$3"
	grabar_log "$1" "$2" "$3"
}

grabar_mensajes_iniciales() {
	mostrar_y_grabar "$0" "INFO" "Inicio de Ejecución de Deployer"
	mostrar_y_grabar "$0" "INFO" "Log de la instalación: \$$ARCHLOG"
	mostrar_y_grabar "$0" "INFO" "Directorio predefinido de Configuración: \$$CONFDIR"
}


obtener_tipo_directorio() {
    echo "$(grep "$1" "tiposDirectorios.def" | sed "s/^[^:]*://")"
}

grabar_log_listado_componentes() {
	mostrar_y_grabar "$0" "INFO" "TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo 9"
	for directorio in "${DIRECTORIOS[@]}"; do
		MSJ=$(obtener_tipo_directorio "$directorio")
		MSJ+=": ${!directorio}"
		
		[ -d "../${!directorio}" ] && ( MSJ+="$(ls ../${!directorio})"; )
		
		mostrar_y_grabar "$0" "INFO" "$MSJ"
		if [ "$#" -ge "2" ]; then
			mostrar_y_grabar "$0" "INFO" "Espacio mínimo libre para flujo de novedades: $1 Mb"
		fi
	done
	#grabar_log "Listado de Otras Variables Definidas"
}

directorios_completos() {
	local directorios=$1
	for directorio in "${directorios[@]}"; do
		if [ "$2" == "" ]; then
			local dir_padre="$directorio"
		else
			local dir_padre="$2/$directorio"
		fi

		if [ -f "$dir_padre" ]; then
			if [ ! -f "../$dir_padre" ]; then
				FALTANTES+=("$dir_padre")
				FALTANTES_STR+="$dir_padre "
			fi
			continue
		fi

		if [ ! -d "../$dir_padre" ]; then
			FALTANTES+=("$dir_padre")
			FALTANTES_STR+="$dir_padre "
			continue
		fi

		local subdirs=$(ls "$dir_padre")
		directorios_completos "$(ls "$dir_padre")" dir_padre
	done
}

instalacion_esta_completa() {
	FALTANTES=()
	FALTANTES_STR=""
	directorios_completos DIRECTORIOS ""
	if [ ${#FALTANTES[@]} -ne "0" ]; then
		return 1
	fi
	return 0
}

grabar_log_instalacion_completa() {
	grabar_log_listado_componentes
	mostrar_y_grabar "$0" "INFO" "Estado de la instalacion: COMPLETA"
	mostrar_y_grabar "$0" "WAR" "Proceso de Instalación Cancelado"
}

grabar_log_instalacion_incompleta() {
	grabar_log_listado_componentes
	mostrar_y_grabar "$0" "INFO" "Componentes faltantes: ${!FALTANTES_STR}"
	mostrar_y_grabar "$0" "INFO" "Estado de la instalación: INCOMPLETA"
}

preguntar_si_no() {
	local RTA=""

	while [[ "$RTA" != "Si" && "$RTA" != "No" ]]; do
		echo -e -n "$2"
		read RTA
	done
	local MSJ_LOG="$2"
	MSJ_LOG+="$RTA"
	local VALOR_RETORNO=1
	if [ $RTA == "Si" ]; then
		grabar_log "$1" "INFO" "$MSJ_LOG"
		VALOR_RETORNO=0
	elif [ $RTA == "No" ]; then
		grabar_log "$1" "INFO" "$MSJ_LOG"
		VALOR_RETORNO=1
	fi
	return $VALOR_RETORNO
}

quiere_completar_instalacion() {
	local MSJ_USUARIO="Desea completar la instalación? (Si-No): "
	preguntar_si_no "$0" "$MSJ_USUARIO"
	return $?
}

confirmar_inicio_instalacion() {
	local MSJ_USUARIO="Iniciando Instalación. Esta Ud. seguro? (Si-No): "
	preguntar_si_no "$0" "$MSJ_USUARIO"
	return $?
}

acepta_terminos_y_condiciones() {
	local MSJ_USUARIO="TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo 9\nAl instalar TP SO7508 Segundo Cuatrimestre 2014 UD. expresa aceptar los términos y condiciones del \"ACUERDO DE LICENCIA DE SOFTWARE\" incluido en este paquete. Acepta? Si – No: "
	preguntar_si_no "$0" "$MSJ_USUARIO"
	return $?
}

grabar_log_perl_no_instalado() {
	mostrar_y_grabar "$0" "ERR" "TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo 9\nPara instalar el TP es necesario contar con Perl 5 o superior. Efectúe su instalación e inténtelo nuevamente. Proceso de Instalación Cancelado"
}

perl_esta_instalado() {
	local MSJ=$(perl -v)
	if [ $? -ne 0 ]; then
		return 1
	else
		local VERSION=$(echo "$MSG" | grep "v[0-9]*\.[0-9]*\.[0-9]*"  | sed "s/^.*v\([0-9]\)*\.[0-9]*\.[0-9]*.*$/\1/")
		if [ "$VERSION" -lt "5" ]; then #cambiar la magia
			return 2
		fi
	fi
	return 0
}

grabar_log_perl_version() {
	mostrar_y_grabar "$0" "$1" "TP SO7508 Segundo Cuatrimestre 2014. Tema E Copyright © Grupo 9\nPerl Version: $(perl -v)"
}

definir_parametros_instalacion() {
	for directorio in "${DIRECTORIOS[@]}"; do
		local MSJ="Defina el "
		MSJ+=$(obtener_tipo_directorio "$directorio")
		MSJ+=" (${!directorio}): "
		mostrar_y_grabar "$0" "INFO" "$MSJ"
		read directorio

		if [ "$directorio" == "$NOVEDIR" ]; then
			mostrar_y_grabar "$0" "INFO" "Defina espacio mínimo libre para el arribo de novedades en Mbytes ($DATASIZE): "
			read DATASIZE
			local ESPACIO=$(df -k . | awk '/[0-9]%/{print $(NF-2)}')
			if [ "$ESPACIO" -lt "$DATASIZE" ]; then
				mostrar_y_grabar "$0" "ERR" "Insuficiente espacio en disco.\nEspacio disponible: $ESPACIO Mb.\nEspacio requerido $DATASIZE Mb\nCancele la instalación o inténtelo nuevamente."
				return 1
			fi
		fi
	done
	#solicitar el ingreso de cualquier otro valor que se requiera para la instalacion o ejecucion
	return 0
}

grabar_log_parametros_instalacion() {
	grabar_log_listado_componentes DATASIZE
	mostrar_y_grabar "$0" "INFO" "Estado de la instalación: LISTA"
}

directorios_son_correctos() {
	preguntar_si_no "$0" "¿Los directorios son correctos? (Si-No): "
	return $?
}

crear_directorios() {
	local DIRECTORIOS_TOTALES=()
	DIRECTORIOS_TOTALES+=${DIRECTORIOS[@]}
	DIRECTORIOS_TOTALES+=("$MAEDIR/saldos")
	DIRECTORIOS_TOTALES+=("$MAEDIR/saldos/ant")
	DIRECTORIOS_TOTALES+=("$ACEPDIR/proc")
	DIRECTORIOS_TOTALES+=("$REPODIR/ant")
	mostrar_y_grabar "$0" "INFO" "Creando Estructuras de directorio. . . ."
	for directorio in "${DIRECTORIOS[@]}"; do
		local DIR="../${!directorio}"
		if [ ! -d "$DIR" ]; then
			mostrar_y_grabar "$0" "INFO" "$DIR"
			mkdir "$DIR"
		fi
	done

}

guardar_archivo_configuracion() {
	if [ -e "../$ARCHCONF" ]; then
		rm "../$ARCHCONF"
	fi
	touch "../$ARCHCONF"
	local FECHA=$(date +"%d/%m/%Y - %H:%M:%S")
	local PATH_ABSOLUTO="$(cd "$(dirname "../../")" && pwd)"
	echo "GRUPO=$PATH_ABSOLUTO/$GRUPO=$USER=$FECHA" >> "../$ARCHCONF"

	for directorio in "${DIRECTORIOS[@]}"; do
		PATH_ABSOLUTO="$(cd "$(dirname "../${!directorio}")" && pwd)"
		echo "$directorio=$PATH_ABSOLUTO/${!directorio}=$USER=$FECHA" >> "../$ARCHCONF"
		if [ "$directorio" == "NOVEDIR" ]; then
			echo "DATASIZE=$DATASIZE=$USER=$FECHA" >> "../$ARCHCONF"
		fi
	done
	#agregar todos los registros que desee
}

obtener_directorios() {
	local PATH_ABSOLUTO="$(cd "$(dirname "../../")" && pwd)/"
	local PATH_ABS_ESCAPE="$(echo "$PATH_ABSOLUTO" | sed 's/[[\.*^$/]/\\&/g')"
	for directorio in "${DIRECTORIOS[@]}"; do
		local PATH_VARIABLE="$(grep "$directorio" "$PATH_ABSOLUTO/$ARCHCONF" | sed "s/^[^=]*=//" | sed "s/=.*//" | sed "s/${PATH_ABS_ESCAPE}//")"
		eval $directorio="'$PATH_VARIABLE'"
	done
}

instalar() {
	crear_directorios
	mostrar_y_grabar "$0" "INFO" "Instalando Programas y Funciones"
	cp -r "$BINDIR/" "../"
	mostrar_y_grabar "$0" "INFO" "Instalando Archivos Maestros y Tablas"
	cp -r "$MAEDIR/" "../"
	mostrar_y_grabar "$0" "INFO" "Actualizando la configuración del sistema"
	guardar_archivo_configuracion
	mostrar_y_grabar "$0" "INFO" "Instalación CONCLUIDA"
}


[ -f "../$ARCHLOG" ] || ( mkdir "../$CONFDIR"; touch "../$ARCHLOG"; )

grabar_mensajes_iniciales

if [ -f "../$ARCHCONF" ]; then
	obtener_directorios
	instalacion_esta_completa
	if [ $? -eq 0 ]; then
		grabar_log_instalacion_completa
		salir
	fi
	grabar_log_instalacion_incompleta
	quiere_completar_instalacion
	chequear_salida $?

	confirmar_inicio_instalacion
	chequear_salida $?

	instalar
	salir
fi

acepta_terminos_y_condiciones
chequear_salida $?

perl_esta_instalado
if [ $? -eq "1" ]; then
	grabar_log_perl_no_instalado
	salir
elif [ $? -eq "2" ]; then
	grabar_log_perl_version "ERR"
	salir
fi

grabar_log_perl_version "INFO"
while true; do
	definir_parametros_instalacion
	chequear_salida
	clear
	grabar_log_parametros_instalacion
	directorios_son_correctos
	if [ $? -eq 0 ]; then
		break;
	fi
done
confirmar_inicio_instalacion
chequear_salida $?
instalar

