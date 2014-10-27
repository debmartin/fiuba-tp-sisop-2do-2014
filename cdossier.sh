#!/bin/bash
#Cdossier

ruta=`pwd`
dir_arch_exp="$ruta/ACEPDIR/"
dir_arch_proc="$ruta/ACEPDIR/proc"
dir_arch_rech="$ruta/RECHDIR"
dir_arch_saldos="$ruta/MAEDIR/saldos/saldos.lis"
dir_arc_repodir="$ruta/REPODIR"
dir_exp_output="$ruta/REPODIR/exp_output"
reg_leidos=0
reg_ignorados=0
reg_reemplazados=0
reg_agregados=0
cumplimiento="CUMPLIMIENTO"
sinCuentaAsociada="SIN CUENTA ASOCIADA"
enGestion="EN GESTION"
remitido="REMITIDO"
aDespacho="A DESPACHO"
enCasillero="EN CASILLERO"

#Inicializo carpetas
dir_repodir_ant="$ruta/REPODIR/ant"
dir_rech="$ruta/RECHDIR"
dir_log="$ruta/LOGDIR"

if [ ! -d "$dir_repodir_ant" ]; then
    mkdir $dir_repodir_ant
fi
if [ ! -d "$dir_rech" ]; then
    mkdir $dir_rech        
fi
if [ ! -d "$dir_log" ]; then
    mkdir $dir_log
fi
if [ ! -d "$dir_arch_proc" ]; then
    mkdir $dir_arch_proc
fi

#FUNCIONES AUXILIARES

# Los archivos de ACEPDIR que se encuentran en ACEPDIR/proc se los mueve a RECHDIR.
function moverDuplicados {
	aceptados=`ls $dir_arch_exp`
	procesados=`ls $dir_arch_proc`	
	for i in $aceptados
	do
		for j in $procesados;
		do
			if [ $i = $j ]; then
				./logging.sh cdossier "Archivo a procesar: $i"
				./logging.sh cdossier "Archivo duplicado. Se rechaza el archivo" INFO
				mv "$dir_arch_exp/$i" "$dir_arch_rech"				
			fi
		done
	done
}


#MAIN

#Inicio Log
./logging.sh cdossier "Inicio de Cdossier" INFO

#Log de lista de expedientes aceptados
cant_arch=0
for archivo in `ls $dir_arch_exp`; do	
	if [ $cant_arch -eq 0 ]; then
		./logging.sh cdossier "Archivos de expediente aceptados:" INFO
	fi
    es_arch=`echo $archivo | grep -c ".*@.*"`
    if [ $es_arch -eq 1 ] && [ -f "$dir_arch_exp/$archivo" ]; then
            ./logging.sh cdossier "$archivo" INFO
            cant_arch=$(($cant_arch + 1))
    fi
done

#Si no hay archivos para procesar, termina el programa:
if [ $cant_arch -eq 0 ]; then
    ./logging.sh cdossier "No hay archivos para procesar" WAR
    ./logging.sh cdossier "Fin de Cdossier" INFO
    exit
fi	

#si hay archivos para procesar:
moverDuplicados
for archivo in `ls $dir_arch_exp`; do	
    es_arch=`echo $archivo | grep -c ".*@.*"`
    if [ $es_arch -eq 1 ] && [ -f "$dir_arch_exp/$archivo" ]; then
    	./logging.sh cdossier "Archivo a procesar: $archivo"            	    	
    	camara=`echo $archivo | cut -d "@" -f 1`
    	tribunal=`echo $archivo | cut -d "@" -f 2`    	
    	while read -r linea || [[ -n "$linea" ]]; do  
            formato_correcto=`echo $linea | grep -c ".*;.*;.*;.*"`
            if [[ $formato_correcto -eq 1 ]]; then
        		ignorado=0;  		
        		reg_leidos=$(($reg_leidos + 1))
        		caratula=`echo $linea | cut -d ";" -f 1`
        		expediente=`echo $linea | cut -d ";" -f 2`
        		estado=`echo $linea | cut -d ";" -f 3`
        		cbu_ini=`echo $linea | cut -d ";" -f 4`
        		cbu=`echo ${cbu_ini} | cut -c 1-22`  #Elimino fin de linea    		
        		tam_cbu=`echo ${#cbu}`    	

        		#determinar accion    		
        		if [[ $estado = $cumplimiento ]]; then    			
        			if [[ $tam_cbu -eq 22 ]]; then
        				saldo=`grep "${cbu}" $dir_arch_saldos | cut -d ";" -f 4`    				
        			fi	
        			accion="PEDIDO URGENTE PARA LIBERAR CUENTA"    	
        		elif [[ $estado = $sinCuentaAsociada ]] && [[ $tam_cbu -le 1 ]]; then    			    			
        			accion="PEDIDO ESTÁNDAR DE ASIGNACION DE CUENTA"    		    			
        		elif [[ $estado = $enGestion ]] || [[ $estado = $remitido ]] && [[ $tam_cbu -le 1 ]]; then
    				accion="ESPERAR 48 HORAS PARA RECLAMAR ASIGNACION DE CUENTA"				
        		elif [[ $estado = $aDespacho ]] || [[ $estado = $enCasillero ]] && [[ $tam_cbu -le 1 ]]; then
        			accion="ESPERAR 96 HORAS PARA RECLAMAR ASIGNACION DE CUENTA"    			
        		elif [[ $estado != $cumplimiento ]]	&& [[ $tam_cbu -gt 1 ]]; then    		
        			saldo=`grep "${cbu}" $dir_arch_saldos | cut -d ";" -f 4`	    				
    				if [[ $tam_cbu -ne 22 ]]; then
    					accion="PEDIDO URGENTE ASIGNAR NUEVA CBU POR CBU INCORRECTA"					
    				elif [[ $saldo = $noHay ]]; then 	#no figura saldo
    					accion="ESPERAR 48 HORAS PARA HACER RECLAMO CON CBU INFORMADA"					
    				else
    					accion="PEDIDO URGENTE EMBARGAR CON CBU INFORMADA"										
    				fi	
    			else			
    				reg_ignorados=$(($reg_ignorados + 1))				
    				ignorado=1				
        		fi	
        		#armar registro de exp_output
        		if [[ ignorado -eq 0 ]]; then
    	    		registro="${expediente};${camara};${tribunal};${caratula};${estado};${cbu};${saldo};${accion}"
    	    		cp $dir_exp_output "$dir_arc_repodir/ant"
    	    		#veo si existe registro con clave expediente+camara+tribunal:
    	    		clave="${expediente};${camara};${tribunal}"	    		
    	    		reemplazar=`cat $dir_exp_output | grep -c "^${clave}"`
    	    		if [ $reemplazar -ne 0 ]; then
                        reg_reemplazados=$(($reg_reemplazados + 1))
                        sed -i "/^${clave_sed}/d" $dir_exp_output  
                        echo $registro >> $dir_exp_output    
    	                
    	            else                    
                        reg_agregados=$(($reg_agregados + 1))
    	            	echo $registro >> $dir_exp_output    	            	
    	    		fi	
    	    	fi	   
            else
                ./logging.sh cdossier "Archivo con formato erróneo. Se rechaza el archivo."
                mv "$dir_arch_exp/$archivo" "$dir_arch_rech"    
                break                
            fi      
		done < $dir_arch_exp/$archivo    	
        if [[ formato_correcto -eq 1 ]]; then
    		mv "$dir_arch_exp/$archivo" "$dir_arch_proc"    
            ./logging.sh cdossier "Cantidad de registros leidos: $reg_leidos" INFO
            ./logging.sh cdossier "Cantidad de registros ignorados: $reg_ignorados" INFO
            ./logging.sh cdossier "Cantidad de registros reemplazados: $reg_reemplazados" INFO
            ./logging.sh cdossier "Cantidad de registros agregados: $reg_agregados" INFO
        fi
    fi	
done

./logging.sh cdossier "Fin de Cdossier" INFO