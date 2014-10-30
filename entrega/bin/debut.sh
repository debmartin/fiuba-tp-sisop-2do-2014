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


PID=`ps a | grep -v "grep" | grep -v "debut" | grep -m 1 "$1" | sed 's-^[^0-9]*\([0-9]*\).*$-\1-'`
if [ -z $PID ]; then
	"$BINDIR/$1" &
	PID=$!
	echo "Se inicio $1. Corriendo bajo pid: $PID"	
else
	echo "El proceso ya esta corriendo bajo el pid $PID"
fi
