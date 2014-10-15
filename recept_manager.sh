#script para iniciar o detener recept


#chequeo que se hayan pasado parametros
if [ $# -eq 0 ]; then
  echo "Ingrese 'start' o 'stop' para correr"
fi


#chequeo si se creo el pipe
pipe='/tmp/receptpipe'

if [ ! -p $pipe ]; then
	mkfifo $pipe
fi


