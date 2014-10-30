################################################################################

README.txt para version 1.0 de DOSSIERE.

Este archivo explica la instalacion del sistema DOSSIERE y su modo de uso.

################################################################################

QUE ES DOSSIERE

	El sistema DOSSIERE permite a sus usuarios elaborar informes y pedidos a
	la justicia federal, a partir de archivos con los saldos en cuentas 
	bancarias afectadas a algún proceso judicial y el estado de los 
	expedientes de la justicia federal.

################################################################################

COMO INSTALAR
	
	Para poder instalar el sistema, primero debe descomprimir el archivador
	descargado:


	DESCOMPRESION:

	El fichero se puede descomprimir en cualquier carpeta. Se recomienda 
	realizarlo en el directorio donde se desea instalar para poder contar 
	con las opciones de reparacion de instalacion mas facilmente en el 
	futuro. Para mover el archivador puede hacer uso del comando:

	mv ./grupo09.tgz [DIRECTORIO DESTINO]
	
	Para descomprimir, se utiliza el siguiente comando, ubicado en la 
	carpeta donde se encuentra el mismo

	tar -zxf grupo09.tgz -C [DESTINO]

	Una vez descomprimido el paquete, se generara una carpeta grupo09, que 
	cuenta con los siguientes directorios:

	. instalador
	. exe
	. datos
	. conf


	INSTALACION:

	1) Colocarse en el directorio instalador y ejecutar Deployer.sh mediante
	el comando:

	bash ./Deployer.sh

	2) Aceptar los terminos y condiciones de la instalacion.

	ACLARACION: Se debera contar con perl v5 o superior para que la 
		    instalacion se concluya.

	3) Proveer los paths de directorios a crear y datos pedidos:

		         Directorio de Configuracion
		         Directorio de Ejecutables
		         Directorio de Datos Maestros y Tablas
		         Directorio de Flujos de Novedades
		         Directorio de Novedades Aceptadas
		         Tamanio maximo de Directorio de Novedades
		         Directorio de Pedidos e Informes de Salida
		         Directorio de Archivos Rechazados
		         Directorio de Log de Comandos
		         Subdirectorio de Resguardo de Archivos Duplicados

	4) Verificar los paths y si estan correctos aceptar.

	5) Instalacion COMPLETA.

	Una vez completada la instalacion, se habran creado los directorios 
	(con todos los subdirectorios que correspondiesen) que ha definido el 
	usuario durante la misma en el directorio grupo09/. Adicionalmente se 
	habran movido los archivos ubicados en grupo09/instalador/data/maestros 
	al Directorio de Datos Maestros y Tablas definido por el usuario.


################################################################################

EJECUCION DEL PROGRAMA

	El programa se ejecuta ingresando el comando:
		
		source initializer.sh	o	. ./initializer.sh

	En este modo, el programa inicializara todos los recursos 
	necesarios para su correcta ejecucion.

INITIER

RECEPT
	
	El programa Recept tiene como objetivo efectuar un filtrado de los
	archivos de novedades de bancos y expedientes. 
	Efectua los siguientes chequeos:
	
	- los archivos deben ser solamente de texto.
	- los nombres de archivos de bancos deben estar formados por una entidad
	  bancaria valida y una fecha valida.
	- los nombres de archivos de expedientes deben estar formados por un
	  camara valida y un tribunal valido.

	Los que no sean correctos seran movidos al directorio de rechazados,
	mientras que los otros serán movidos al directorio de aceptados.
		


FSOLDES

	El programa Fsoldes tiene como objetivo efectuar la actualizacion de saldos a
	partir de los archivos de novedades de bancos. Es invocado por Recept y se
	ejecuta desde la línea de comando como
	
		  ./fsoldes.sh
		  
	Cada vez que hay archivos de novedades en la carpeta de aceptados se verifica
	la fecha de la entidad en el bancos.dat para ver si se procesa o no el archivo
	en cuestión. 
	Si la fecha es correcta (mayor a la almacenada en el .dat para esa entidad) se 
	contruyen y se toman todos los datos del registro para poder actualizar tanto 
	el .dat mencionado como el saldos.lis que contiene todos los saldos leidos. 
	Además cada vez que se lee un registro se verifican que los datos sean
	correctos y no contengan formatos erroneos. En cuanto a la  actualización de
	saldos.lis, se reemplazan todos los registros de la entidad en cuestión por los 
	leidos.
	Si la fecha es anterior o igual, se procede a enviar el archivo de novedades
	a la carpeta de rechazados.

	
CDOSSIER

	El programa Cdossier se encarga de procesar registros de archivos de
	expedientes y determinar en base al estado del registro y si tiene o
	no CBU la accion a ejecutar sobre la cuenta. Es invocado por Recept y
	se ejecuta desde la línea de comandos como
	
		./cdossier.sh

	En el caso de que el archivo de expedientes ya haya sido procesado, se
	rechaza el archivo y se lo envia a la carpeta RECHDIR. También se rechaza
	el archivo si el nombre del archivo o los registros no cumplen con el
	formato establecido.
	Para procesar los registros, el programa comprueba condiciones sobre el
	estado del expediente y el cbu. En caso de ser necesario, busca el saldo
	correspondiente al registro en la lista maestra de saldos que crea Fsoldes
	Si el registro no cumple con ninguna de las condiciones buscadas, se lo
	rechaza y se cuenta como rechazado.
	Finalmente, se crea un registro con los datos obtenidos del expediente, la
	accion determinada y el saldo, si corresponde. Ese registro se reemplaza o
	agrega en el archivo exp_output.
			


################################################################################

LISTE
	
	El programa Liste se encarga de elaborar informes y pedidos, en base a 
	los datos recopilados por el sistema Dossiere.
	Se ejecuta desde la línea de comandos como

		./Liste.pl

	Hay 2 modos de trabajo: elaboración de informes y eleaboración de 
	pedidos. En ambos modos se pueden usar diferentes filtros al hacer 
	consultas sobre los datos. Los mismos son:
	Cámara: Permite elegir mostrar resultados que contengan una, varias o 
	todas las cámaras.
	Tribunal: Permite elegir mostrar resultados que contengan uno, varios o 
	todos los tribunales.
	Expediente: Permite elegir mostrar resultados que contengan uno, varios 
	o todos los expedientes.
	Estado informado: Permite elegir mostrar resultados que contengan uno, 
	varios o todos los estados.
	Saldo: Permite elegir mostrar resultados que no contengan saldo, tengan 
	un saldo mayor o menor un número, o que tengas un saldo entre dos 
	números.
	Tipo de pedido: Solo disponible en el modo pedido. Permite elegir 
	mostrar resultados que sean de un solo tipo, de varios tipos o de todos 
	los tipos de pedidos.
	Nivel de urgencia: Solo disponible en el modo pedido. Permite elegir 
	mostrar los resultados por un nivel de urgencia, varios niveles, o 
	todos los niveles de urgencia.

	Los resultados pueden mostrarse por pantalla o grabarse a un archivo.
	En el modo de eleaboración de informes se toman los datos del archivo 
	exp_output, generado por Cdossier, y se muestran en el mismo formato. 
	Si se graban a un archivo, el mismo se puede usar como entrada para el 
	modo de elaboración de pedidos.
	En el modo de elaboración de pedidos se elaboran los pedidos a la 
	justicia federal, en base a los datos del archivo exp_output, o de uno 
	o varios de los archivos de informe generados por este mismo programa. 
	Cada pedido se muestra con un formato predeterminado, dependiendo del 
	tipo de pedido y la acción a efectuar.


################################################################################

AUTORES

	Barro Beotegui, Matías
	Di Rocco, Federico Santiago
	Lafroce, Matias
	Martin, Débora Elisa
	Merlo Schurmann, Bruno
	Sella Faena, Jasmina


################################################################################
