#!/bin/bash

#procesar $archivo saldos.tab dir_saldos
function procesarArchivo {
	dir_arch_proc="$HOME/tp/ACEPDIR"
	./logging.sh fsoldes "Archivo a procesar: <$1> \n" INFO
	entidad=`echo $1 | sed 's-\(^[A-Z]*\)_[0-9]*-\1-'` #I
	fecha=`echo $1 | sed 's-^[A-Z]*_\([0-9]*\)-\1-'`  #I
		
	#Punto 3
	arch_bancos="$HOME/tp/MAEDIR/bancos.dat"
	cod_entidad=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 2`
	primer_campo_cbu=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 4`
	ubic_campo_saldo=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 5`
	format=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 6`
	format_cbu=`echo ${format} | tr -d '\n'` #Elimino fin de linea
	reg_rech=0
	reg_acept=0
	reg_leidos=0
	reg_elim=0
	creado_temp=false
	while read -r linea || [[ -n "$linea" ]]; do
		reg_leidos=$(($reg_leidos + 1))
		if [[ $format_cbu == 1 ]]; then 
		 	cbu=`echo $linea | cut -d ";" -f $primer_campo_cbu`
		elif [[ $format_cbu == 2 ]]; then
			primer_bloque=`echo $linea | cut -d ";" -f $primer_campo_cbu`
			segundo_bloque=`echo $linea | cut -d ";" -f $((primer_campo_cbu + 1))`
			cbu=$primer_bloque$segundo_bloque
		elif [[ $format_cbu == 5 ]]; then	
			primer_bloque=`echo $linea | cut -d ";" -f $primer_campo_cbu`
			segundo_bloque=`echo $linea | cut -d ";" -f $((primer_campo_cbu + 1))`
			tercer_bloque=`echo $linea | cut -d ";" -f $((primer_campo_cbu + 2))`
			cuarto_bloque=`echo $linea | cut -d ";" -f $((primer_campo_cbu + 3))`
			quinto_bloque=`echo $linea | cut -d ";" -f $((primer_campo_cbu + 4))`
			cbu=$primer_bloque$segundo_bloque$tercer_bloque$cuarto_bloque$quinto_bloque
		else
			./logging.sh fsoldes "Formato especificado del CBU no valido. Debe ser 1, 2 o 5. \n" ERR
			reg_rech=$(($reg_rech + 1))
			continue
		fi

		#Valido CBU de 22 numeros (Punto 6)
		es_cbu_valido=`echo ${#cbu}`

		if [ $es_cbu_valido -eq 22 ]; then
			
			#Armo registro para saldos.lis (Punto 7)
			saldo=`echo $linea | cut -d ";" -f $ubic_campo_saldo`
			registro="${1};${cod_entidad};${cbu};${saldo}"
			#Escribo en archivo temporal el registro
			dir_temp="$HOME/tp/temp"
			arch_temp="$HOME/tp/temp/temp.txt"
			if [ ! -d "$dir_temp" ]; then
				mkdir $dir_temp
				creado_temp=true
			fi
			if [ ! -f "$arch_temp" ]; then
				touch $arch_temp
				chmod +x $arch_temp
			fi
			echo $registro >> $arch_temp
			reg_acept=$(($reg_acept + 1))
		else
			linea_rech=`echo ${linea} | tr -d '\n'` #Elimino fin de linea
			./logging.sh fsoldes "Error en CBU. Registro original <$linea_rech>" ERR
			./logging.sh fsoldes "Se rechaza el registro.\n" INFO
			reg_rech=$(($reg_rech + 1))
		fi
	done < "$dir_arch_proc/$1"		
			
	#Resguardar archivos (Punto 8 y 9)
	#Verificar que si /ant esta vacio entonces no tiene que copiar nada
	if [ "$creado_ant" == false ]; then
		cp "$2" "$3/ant"
		cp "$arch_saldos_lis" "$3/ant"

	fi

	#Actualizo saldos.lis (Punto 10)
	es_reemplazo=`cat $arch_saldos_lis | grep -c "^${entidad}"`
	if [ $es_reemplazo -ne 0 ]; then
		#Eliminar cada linea de reemplazo
		while read -r linea || [[ -n "$linea" ]]; do
			es_reemplazo_linea=`echo $linea | grep -c "^${entidad}"`
			if [ $es_reemplazo_linea -ne 0 ]; then
				reg_elim=$(($reg_elim + 1))
			fi
			sed -i "/^${entidad}/d" $arch_saldos_lis
		done < "$arch_saldos_lis"
	fi
	#Si se creo temporal (hay registros validos), actualizo saldos.lis
	arch_temp="$HOME/tp/temp/temp.txt"
	if [ -f "$arch_temp" ]; then
		while read -r linea; do
			echo $linea >> $arch_saldos_lis
		done < "$arch_temp"
	fi

	#Actualizar saldos.tab (Punto 11) 
	if [ $reg_acept -ne 0 ]; then
		registro="${entidad};${cod_entidad};${fecha}"
		echo $registro >> $2
	fi

	#Mover archivo procesado a proc (Punto 12)
	arch_proc_fin="$HOME/tp/ACEPDIR/proc"
	mv "$dir_arch_proc/$1" "$arch_proc_fin"
	
	#Grabar en el log (Punto 13)
	./logging.sh fsoldes "Cantidad de registros leidos: $reg_leidos" INFO
	./logging.sh fsoldes "Cantidad de registros aceptados: $reg_acept" INFO
	./logging.sh fsoldes "Cantidad de registros rechazados: $reg_rech" INFO
	./logging.sh fsoldes "Cantidad de registros eliminados: $reg_elim \n" INFO
	
	#Elimino temporal si fue creado
	dir_temp="$HOME/tp/temp"
	if [[ "$creado_temp" == true ]]; then
		rm -r $dir_temp
	fi
}


#--------------------------MAIN--------------------------------------

#Punto 1
./logging.sh fsoldes "Inicio de Fsoldes \n" INFO

#Inicializo carpetas, saldos.tab y saldos.lis en blanco
dir_saldos="$HOME/tp/MAEDIR/saldos/"
dir_saldos_ant="$HOME/tp/MAEDIR/saldos/ant/"
arch_saldos="$HOME/tp/MAEDIR/saldos/saldos.tab"
arch_saldos_lis="$HOME/tp/MAEDIR/saldos/saldos.lis"
if [ ! -d "$dir_saldos" ]; then
	mkdir $dir_saldos
fi
if [ ! -d "$dir_saldos_ant" ]; then
	mkdir $dir_saldos_ant
	creado_ant=true
else
	creado_ant=false
fi
if [ ! -f "$arch_saldos" ]; then
	touch $arch_saldos
	chmod +x $arch_saldos
fi
if [ ! -f "$arch_saldos_lis" ]; then
	touch $arch_saldos_lis
	chmod +x $arch_saldos_lis
fi

#Listo todos los archivos que son para procesar
dir_arch_proc="$HOME/tp/ACEPDIR"
cant_arch=0
./logging.sh fsoldes "Archivos de saldos a procesar:" INFO
for archivo in `ls $dir_arch_proc`; do
	es_arch=`echo $archivo | grep -c "^[A-Z]*_[0-9]\{8\}*"`
	if [ $es_arch -eq 1 ] && [ -f "$dir_arch_proc/$archivo" ]; then
		./logging.sh fsoldes "$archivo" INFO
		cant_arch=$(($cant_arch + 1))
	fi
done

#Punto 2
if [ $cant_arch -eq 0 ]; then
	./logging.sh fsoldes "No hay archivos para procesar \n" WAR
	./logging.sh fsoldes "Fin de Fsoldes \n" INFO
	exit
fi

for archivo in `ls $dir_arch_proc`; do
	es_arch=`echo $archivo | grep -c "^[A-Z]*_[0-9]*"`
	
	#Agarro solo los archivos que cumplen con entidad_fecha
	if [ $es_arch -eq 1 ] && [ -f "$dir_arch_proc/$archivo" ]; then
		entidad=`echo $archivo | sed 's-\(^[^0-9]*\)_[0-9]*-\1-'`
		fecha=`echo $archivo | sed 's-^[^0-9]*_\([0-9]*\)-\1-'`
		esta_entidad=`cat $arch_saldos | grep -c "^${entidad}"`
		arch_bancos="$HOME/tp/MAEDIR/bancos.dat"
		cod_entidad=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 2`
		
		#Si no esta la entidad en el saldos.tab solo proceso el archivo
		if [ $esta_entidad -eq 0 ]; then
			procesarArchivo $archivo $arch_saldos $dir_saldos
		else

			#Si la entidad esta en saldos.tab, verifico la fecha y actualizo el registro de la entidad
			fecha_saldo=`grep "^${entidad}" $arch_saldos | cut -d ";" -f 3`
			if [ $fecha_saldo -lt $fecha ]; then 
				procesarArchivo $archivo $arch_saldos $dir_saldos
				sed -i "/^${entidad}/d" $arch_saldos
				registro="${entidad};${cod_entidad};${fecha};"
				echo $registro >> $arch_saldos
			else 

				#El archivo no cumple con la fecha (antigua o igual)
				arch_rechdir="$HOME/tp/RECHDIR"
				mv "$dir_arch_proc/$archivo" "$arch_rechdir"
				if [ $fecha_saldo -gt $fecha ]; then
					./logging.sh fsoldes "Fecha del Archivo anterior a la existente. Se rechaza el archivo. \n" WAR
				else
					./logging.sh fsoldes "Archivo Duplicado. Se rechaza el archivo. \n" WAR
				fi
			fi
		fi
	fi
done
./logging.sh fsoldes "Fin de Fsoldes \n" INFO