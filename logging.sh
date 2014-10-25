#!/usr/bin/env bash

CONF_FILE="$CONFDIR/deployer.conf" #HAY QUE PONER LA QUE CORRESPONDA
TRIM_LOG_SIZE=50

# Recibe el nombre de la variable env de donde obtener el valor y devuelve el mismo
getEnvVarValue() {
    VAR_NAME="$1"
    grep "$VAR_NAME" "$CONF_FILE" | sed "s/^[^=]*=\([^=]*\)=.*\$/\1/"
}

# Obtiene el proceso que esta llamando al logger y devuelve el archivo de log que corresponda
# Chequea que si es el Deployer el .log esta en la carpeta conf
getFilePath() {
    CALLER="$1"
    if [ $CALLER == "Deployer" ] 
    then
        echo "$CONFDIR/$CALLER.$LOGEXT" # $grupo/conf/Deployer.log
    else
        echo "$HOME/tp/LOGDIR/$CALLER.log" #ACA PONGAN SU DIRECCION DE RUTA PARA QUE AL MENOS LES ANDE
        #echo "$LOGDIR/$CALLER.$LOGEXT" # $grupo/logdir/Proceso.log
    fi
}

# Recorta el archivo de log, dejando las ultimas TRIM_LOG_SIZE lineas
trimLogFile() {
    FILE="$1"
    AUX_FILE="$1.aux"
    DATE=$(date +"%d/%m/%Y %H:%M:%S")
    echo "$DATE - Log excedido" > "$AUX_FILE"
    tail --lines="$TRIM_LOG_SIZE" "$FILE" >> "$AUX_FILE"
    rm "$FILE"
    mv "$AUX_FILE" "$FILE"
}

# Escribe la información al archivo de log
log () {
    CALLER="$1"
    MSG="$2"
    TYPE="$3"
    FILE=$(getFilePath "$CALLER")
    DATE=$(date +"%d/%m/%Y %H:%M:%S")
    echo -e "$DATE - $USER $CALLER $TYPE: $MSG" >> "$FILE"
    return 0
}


# Obtiene el nombre de archivo y el LOGSIZE
FILE=$(getFilePath "$1")
touch "$FILE"

LOGSIZE=1024 #LE PUSE 1024 PARA QUE ANDE AHORA, VA LO DE ABAJO EN REALIDAD
#LOGSIZE=$(getEnvVarValue LOGSIZE)

# Chequea si hay que recortar
FILE_LINES=$(wc -l < "$FILE")
if [ "$FILE_LINES" -gt "$LOGSIZE" ]
then
    trimLogFile "$FILE"
fi

# Loguea
if [ "$#" -gt 3 -o "$#" -lt 2 ]
then
    echo -e "\nUso: logging comando mensaje [tipo_mensaje]\n\n\tTipo de mensaje puede ser INFO, WAR o ERR.\n\tSi se omite, por defecto es INFO.\n"
    exit -1
elif [ "$#" -eq 2 ]
then
    # Si no tiene tercer parametro el default es INFO
    log "$1" "$2" "INFO"
else
    log "$1" "$2" "$3"
fi

exit 0
