#!/bin/bash

#procesar $archivo saldos.tab dir_saldos
function procesarArchivo {
	dir_arch_proc="$ACEPDIR"
	./logging.sh fsoldes "Archivo a procesar: <$1> \n" INFO
	entidad=`echo $1 | sed 's-\(^[A-Z]*\)_[0-9]*-\1-'` #I
	fecha=`echo $1 | sed 's-^[A-Z]*_\([0-9]*\)-\1-'`  #I
		
	#Punto 3
	arch_bancos="$MAEDIR/bancos.dat"
	cod_entidad=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 2`
	primer_campo_cbu=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 4`
	if [ -z $(echo $primer_campo_cbu | grep "^[0-9]") ]; then
		./logging.sh fsoldes "Error en primer campo del cbu en <bancos.dat> de la entidad a procesar (no es un número con formato N)." ERR
		./logging.sh fsoldes "Se rechaza el archivo <$archivo>." ERR
		./move.pl "$dir_arch_proc/$archivo" "$RECHDIR/" fsoldes
		continue
	fi
	ubic_campo_saldo=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 5`
	if [ -z $(echo $ubic_campo_saldo | grep "^[0-9]") ]; then
		./logging.sh fsoldes "Error en ubicacion del campo saldo en <bancos.dat> de la entidad a procesar (no es un número con formato N)." ERR
		./logging.sh fsoldes "Se rechaza el archivo <$archivo>." ERR
		./move.pl "$dir_arch_proc/$archivo" "$RECHDIR/" fsoldes
		continue
	fi
	format=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 6`
	format_cbu=`echo ${format} | tr -d '\n'` #Elimino fin de linea
	if [ -z $(echo $format_cbu | grep "^[0-9]") ]; then
		./logging.sh fsoldes "Error en formato del cbu en <bancos.dat> de la entidad a procesar (no es un número con formato N)." ERR
		./logging.sh fsoldes "Se rechaza el archivo <$archivo>." ERR
		./move.pl "$dir_arch_proc/$archivo" "$RECHDIR/" fsoldes
		continue
	fi
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
		if [ ! -z $(echo $cbu | grep "^[0-9]\{22\}") ]; then
			
			#Armo registro para saldos.lis (Punto 7)
			saldo=`echo $linea | cut -d ";" -f $ubic_campo_saldo`
			#if [ -z $(echo $saldo | grep "^-\?[0-9]*,\?[0-9]*") ]; then
			#	./logging.sh fsoldes "Error en saldo (no es un numero). Registro original <$linea>" ERR
			#	./logging.sh fsoldes "Se rechaza el registro." ERR
			#	continue
			#fi
			registro="${1};${cod_entidad};${cbu};${saldo}"
			#Escribo en archivo temporal el registro
			dir_temp="$MAEDIR/saldos/temp"
			arch_temp="$MAEDIR/saldos/temp/temp_saldos.txt"
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
	cp "$2" "$3/ant"
	cp "$arch_saldos_lis" "$3/ant"

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
	arch_temp="$MAEDIR/saldos/temp/temp_saldos.txt"
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
	arch_proc_fin="$ACEPDIR/proc/"
	./move.pl "$dir_arch_proc/$1" "$arch_proc_fin" fsoldes
	
	#Grabar en el log (Punto 13)
	./logging.sh fsoldes "Cantidad de registros leidos: $reg_leidos" INFO
	./logging.sh fsoldes "Cantidad de registros aceptados: $reg_acept" INFO
	./logging.sh fsoldes "Cantidad de registros rechazados: $reg_rech" INFO
	./logging.sh fsoldes "Cantidad de registros eliminados: $reg_elim \n" INFO
	
	#Elimino temporal si fue creado
	dir_temp="$MAEDIR/saldos/temp"
	if [[ "$creado_temp" == true ]]; then
		rm -r $dir_temp
	fi
}


#--------------------------MAIN--------------------------------------

#Punto 1
./logging.sh fsoldes "Inicio de Fsoldes \n" INFO

#Verifico si el ambiente fue inicialiazado correctamente
if [ $INITIALIZED -ne 1 ]; then
	./logging.sh fsoldes "Ambiente no inicializado, no se puede ejecutar Fsoldes \n" ERR
	./logging.sh fsoldes "Fin de Fsoldes \n\n" INFO
	exit
fi

#Inicializo carpetas, saldos.tab y saldos.lis en blanco (deberian estar creadas por el Deployer)
dir_saldos="$MAEDIR/saldos/"
dir_saldos_ant="$MAEDIR/saldos/ant/"
arch_saldos="$MAEDIR/saldos/saldos.tab"
arch_saldos_lis="$MAEDIR/saldos/saldos.lis"
dir_acept_proc="$ACEPDIR/proc"
if [ ! -d "$dir_saldos" ]; then
	mkdir $dir_saldos
fi
if [ ! -d "$dir_saldos_ant" ]; then
	mkdir $dir_saldos_ant
fi
if [ ! -f "$arch_saldos" ]; then
	touch $arch_saldos
	chmod +x $arch_saldos
fi
if [ ! -f "$arch_saldos_lis" ]; then
	touch $arch_saldos_lis
	chmod +x $arch_saldos_lis
fi

if [ ! -d "$dir_acept_proc" ]; then
	mkdir $dir_acept_proc
fi
arch_bancos="$MAEDIR/bancos.dat"
if [ ! -f $arch_bancos ]; then
	./logging.sh fsoldes "El archivo de bancos <bancos.dat> no se encuentra. \n" ERR
	./logging.sh fsoldes "Fin de Fsoldes \n\n" INFO
	exit
fi

#Listo todos los archivos que son para procesar
dir_arch_proc="$ACEPDIR"
cant_arch=0
./logging.sh fsoldes "Archivos de saldos a procesar:" INFO
for archivo in `ls $dir_arch_proc`; do
	es_arch=`echo $archivo | grep -c "^[A-Z]*_[0-9]\{8\}"`
	if [ $es_arch -eq 1 ] && [ -f "$dir_arch_proc/$archivo" ]; then
		./logging.sh fsoldes "$archivo" INFO
		cant_arch=$(($cant_arch + 1))
	fi
done

#Punto 2
if [ $cant_arch -eq 0 ]; then
	./logging.sh fsoldes "No hay archivos para procesar. \n" WAR
	./logging.sh fsoldes "Fin de Fsoldes \n\n" INFO
	exit
fi

for archivo in `ls $dir_arch_proc`; do
	es_arch=`echo $archivo | grep -c "^[A-Z]*_[0-9]\{8\}"`
	
	#Agarro solo los archivos que cumplen con entidad_fecha
	if [ $es_arch -eq 1 ] && [ -f "$dir_arch_proc/$archivo" ]; then
		entidad=`echo $archivo | sed 's-\(^[^0-9]*\)_[0-9]*-\1-'`
		fecha=`echo $archivo | sed 's-^[^0-9]*_\([0-9]*\)-\1-'`
		esta_entidad=`cat $arch_saldos | grep -c "^${entidad}"`
		cod_entidad=`grep "^${entidad}" $arch_bancos | cut -d ";" -f 2`
		#Verifico que el codigo de entidad sea correcto en el bancos.dat
		if [ -z $(echo $cod_entidad | grep "^[0-9]*") ]; then
			./logging.sh fsoldes "Error en codigo de entidad en <bancos.dat> de la entidad a procesar (no es un número con formato NNN)." ERR
			./logging.sh fsoldes "Se rechaza el archivo <$archivo>." ERR
			./move.pl "$dir_arch_proc/$archivo" "$RECHDIR/" fsoldes
			continue
		fi
		
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
				dir_rechdir="$RECHDIR/"
				./move.pl "$dir_arch_proc/$archivo" "$dir_rechdir" fsoldes
				if [ $fecha_saldo -gt $fecha ]; then
					./logging.sh fsoldes "Fecha del Archivo anterior a la existente. Se rechaza el archivo. \n" WAR
				else
					./logging.sh fsoldes "Archivo Duplicado. Se rechaza el archivo. \n" WAR
				fi
			fi
		fi
	fi
done
./logging.sh fsoldes "Fin de Fsoldes \n\n" INFO
exit