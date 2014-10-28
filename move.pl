#!/usr/bin/env perl

#package Move;
#use Exporter;
#@ISA = ('Exporter');
#@EXPORT = ('move');
#@EXPORT_OK = ('move');

use File::Spec::Functions qw(catfile);
use File::Copy qw(copy);
use File::Basename qw(fileparse);

# Recibe el path de un directorio, y chequea si existe un subdirectorio "dup"
sub checkDup {
    my ($dup) = catfile(@_[0], "dup");
    return (-e -d $dup);
}

# Recibe una lista de archivos a revisar, y devuelve el numero de secuencia a
# utilizar para archivos duplicados
sub getNextSecuenceNumber {
    my ($dir_path, @files) = @_;
    my ($ret_n) = 0;
    foreach (@files) {
        #Aca no sé bien que poner, si no esta completo el path no anda
        my ($file) = catfile($dir_path, $_);
        next unless (-f $file);
        ($file =~ /(\d{0,3}$)/);
        $ret_n = $1 if ($ret_n < $1);
    }
    return ++$ret_n;
}

# Recibe el path de un directorio y el nombre de un archivo duplicado. Devuelve
# la ruta completa donde se movera el archivo (incluyendo el subdirectorio "dup"
# y el numero de secuencia correspondiente), o una cadena vacia si no se pudo 
# abrir el directorio destino.
sub assembleExistingDestFilePath {
    my ($destination, $file_name) = @_;
    my ($dup_destination) = catfile($destination, "dup");
    opendir(DEST_DIR_H, $dup_destination) || return "";
    my ($secuence_n) = getNextSecuenceNumber($dup_destination, readdir(DEST_DIR_H));
    closedir(DEST_DIR_H);
    return (catfile($dup_destination, ($file_name.".".$secuence_n)));
}

# Recibe un archivo origen y un destino (rutas completas). Copia el archivo al
# destino, y elimina el primero. Devuelve 1 si las dos operaciones tuvieron
# exito, 0 si alguna fallo
sub moveFile {
    my ($origin, $destination) = @_;
    return (copy("$origin", "$destination") && unlink("$origin"));
}

# Recibe un archivo origen, un destino y el comando que invoca a move. Mueve el
# archivo al destino, creando un directorio "dup" y agregando un numero de 
# secuencia al archivo si el mismo ya existia. Devuelve 0 si tuvo exito, 1 si 
# el origen no existe, 2 si el destino no existe, 3 si no se pudo acceder al 
# directorio destino y 4 si no se pudo mover el archivo. Logguea el resultado en
# el log del comando que lo invoca, o en uno propio si no se recibio el comando.
# El numero de secuencia es unico para todos los archivos (si estan duplicados 
# los archivos fA y fB, se guardan como fA.1 y fB.2)
sub move {
    #my ($origin, $original_file) = (@_[0] =~ /^\s*(.*\/)(.*(?:\.*.*)*)\s*$/);
    my ( $original_file,$origin) = fileparse(@_[0]);
    #my ($destination, $copy_file) = (@_[1] =~ /^\s*(.*\/)(.*(?:\.*.*)*)\s*$/);
    my ($copy_file, $destination) = fileparse(@_[1]);
    my ($invoking_command) = @_[2];
    $invoking_command = "move" if (! $invoking_command);
    $copy_file = $original_file if (! $copy_file);
    my ($origin_full) = @_[0];
    my ($destination_full) = catfile($destination, $copy_file);
    if (! -e $origin_full) {
        system("bash logging.sh $invoking_command \"No existe el origen\" ERR");
        return 1
    }
    if (! -e $destination) {
        system("bash logging.sh $invoking_command \"No existe el destino\" ERR");
        return 2
    }
    if ($origin eq $destination) {
        system("bash logging.sh $invoking_command \"El origen y el destino son iguales\" INFO");
        return 0;
    }
    # Chequea si existe el archivo en la carpeta destino
    if (-f -e $destination_full) {
        # Chequea si existe la carpeta "dup", y la crea si no es asi
        mkdir(catfile($destination, "dup")) if (! checkDup(destination));
        # Añade el numero de secuencia a la ruta del archivo
        $destination_full = assembleExistingDestFilePath($destination, $copy_file);
        if (! $destination_full) {
            system("bash logging.sh $invoking_command \"No se pudo acceder a la carpeta destino (permisos insuficientes?)\" ERR");
            return 3;
        }
    }
    if (! moveFile($origin_full, $destination_full)) {
        system("bash logging.sh $invoking_command \"No se pudo mover a la carpeta destino (permisos insuficientes?)\" ERR");
        return 4;
    }
    system("bash logging.sh $invoking_command \"Se movió el archivo $original_file\" INFO");
    return 0
}

$ret = move(@ARGV);
exit $ret;
