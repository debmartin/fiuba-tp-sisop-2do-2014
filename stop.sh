#!/bin/bash

#chequeo que los parametros sean correctos
if [ ! $# -eq 1 ]; then
	echo "Error: parametros incorrectos, solo debes proporcionar un script"
	exit 1
fi 

if [ ! -f "$BINDIR/$1" ]; then
	echo "El archivo a ejecutar no existe"
	exit 2
fi

PID=`ps a | grep -v "grep" | grep -v "stop" | grep -m 1 "$1" | sed 's-^[^0-9]*\([0-9]*\).*$-\1-'`
if [ -z $PID ]; then
	echo "No se ha encontrado ningun proceso asociado a ese script."
else
	echo "Se ha detenido el proceso $1. PID: $PID"
	kill $PID
fi
