#!/usr/bin/env perl

use File::Spec::Functions qw(catfile);
use Storable qw(dclone);

use Env qw(INITIALIZED REPODIR MAEDIR); # Variables de ambiente
#$INITIALIZED = 1; # Borrar cuando esten las variables de ambiente
#$REPODIR = "/home/chulmi/Facu/SisOp/2c2014/repodir"; # Borrar cuando esten las variables de ambiente
#$MAEDIR = "/home/chulmi/Facu/SisOp/2c2014/maedir"; # Borrar cuando esten las variables de ambiente
$EXP_OUT = "exp_output";
$MAE_CAMERAS = "camaras.dat";
$MAE_COURTS = "pjn.dat";
$MAE_BANKS = "bancos.dat";
$BALANCES_SUBDIR = "saldos";
$MAE_BALANCES = "saldos.lis";
$MODE_REPORT = 1;
$MODE_REQUISITION = 2;
$MODE_HELP = 3;
$MODE_EXIT = 4;
$EXP_ID = "n";
$CAMERA_ID = "c";
$COURT_ID = "t";
$STATE_ID = "e";
$BALANCE_ID = "s";
$TYPE_ID = "p";
$URGENCY_ID = "u";
$FIELDS_COUNT = 8;
$EXP_POSITION = 0;
$CAMERA_POSITION = 1;
$COURT_POSITION = 2;
$COVER_POSITION = 3;
$STATE_POSITION = 4;
$CBU_POSITION = 5;
$BALANCE_POSIOTION = 6;
$ACTION_POSITION = 7;
$FIELD_NO_DATA = "N/A";
$BALANCE_RULE_NONE = 1;
$BALANCE_RULE_LESSER = 2;
$BALANCE_RULE_GREATER = 3;
$BALANCE_RULE_BETWEEN = 4;
%BALANCE_RULES = ($BALANCE_RULE_NONE => "Sin saldo",
                  $BALANCE_RULE_LESSER => "Menor",
                  $BALANCE_RULE_GREATER => "Mayor",
                  $BALANCE_RULE_BETWEEN => "Entre dos");
@STATES = ("EN GESTION", "REMITIDO", "A DESPACHO", "SIN CUENTA ASOCIADA", "CUMPLIMIENTO", "EN CASILLERO");
$ACTION_GARNISHMENT = "PEDIDO URGENTE EMBARGAR CON CBU INFORMADA";
$ACTION_INFORM = "ESPERAR 48 HORAS PARA HACER RECLAMO CON CBU INFORMADA";
$ACTION_RELEASE = "PEDIDO URGENTE PARA LIBERAR CUENTA";
$ACTION_ASSIGN_URG = "PEDIDO URGENTE ASIGNAR NUEVA CBU POR CBU INCORRECTA";
$ACTION_ASSIGN_1_DAYS = "PEDIDO ESTÁNDAR DE ASIGNACION DE CUENTA";
$ACTION_ASSIGN_2_DAYS = "ESPERAR 48 HORAS PARA RECLAMAR ASIGNACION DE CUENTA";
$ACTION_ASSIGN_4_DAYS = "ESPERAR 96 HORAS PARA RECLAMAR ASIGNACION DE CUENTA";
$ACTION_TYPE_GARNISHMENT = "Embargo";
$ACTION_TYPE_INFORM = "Información de saldo";
$ACTION_TYPE_RELEASE = "Liberación";
$ACTION_TYPE_ASSIGN = "Asignación";
%ACTIONS_BY_TYPE = ($ACTION_TYPE_GARNISHMENT => [$ACTION_GARNISHMENT],
					$ACTION_TYPE_INFORM => [$ACTION_INFORM],
					$ACTION_TYPE_RELEASE => [$ACTION_RELEASE],
					$ACTION_TYPE_ASSIGN => [$ACTION_ASSIGN_URG, $ACTION_ASSIGN_1_DAYS, $ACTION_ASSIGN_2_DAYS, $ACTION_ASSIGN_4_DAYS]);
%ACTIONS_BY_DAYS = (0 => [$ACTION_GARNISHMENT, $ACTION_RELEASE, $ACTION_ASSIGN_URG], 
					1 => [$ACTION_ASSIGN_1_DAYS], 
					2 => [$ACTION_INFORM, $ACTION_ASSIGN_2_DAYS], 
					3 => [], 
					4 => [$ACTION_ASSIGN_4_DAYS]);
$FILTER_NO_MORE = "x";
%COMMON_FILTERS = ($CAMERA_ID => "Cámaras", 
				   $COURT_ID => "Tribunales", 
				   $EXP_ID => "Expedientes", 
				   $STATE_ID => "Estado", 
				   $BALANCE_ID => "Saldo");
%REQUISITION_FILTERS = ($TYPE_ID => "Tipo de pedido", 
						$URGENCY_ID => "Urgencia");
%FILTER_VALUES_SUBS = ($CAMERA_ID => getCamerasFilterValues,
					   $COURT_ID => getCourtsFilterValues,
					   $EXP_ID => getExpFilterValues,
					   $STATE_ID => getStateFilterValues,
					   $BALANCE_ID => getBalanceFilterValues,
					   $TYPE_ID => getTypeFilterValues,
					   $URGENCY_ID => getUrgencyFilterValues);
%FILTER_PROCESS_SUBS = ($CAMERA_ID => processCamerasFiltering,
						$COURT_ID => processCourtsFiltering,
						$EXP_ID => processExpFiltering,
						$STATE_ID => processStateFiltering,
						$BALANCE_ID => processBalanceFiltering,
						$TYPE_ID => processTypeFiltering,
						$URGENCY_ID => processUrgencyFiltering);
%BALANCE_FILTER_SUBS = ($BALANCE_RULE_NONE => processBalanceNone,
                        $BALANCE_RULE_LESSER => processBalanceLesser,
                        $BALANCE_RULE_GREATER => processBalanceGreater,
                        $BALANCE_RULE_BETWEEN => processBalanceBetween);
%ACTION_OUTPUT_SUBS = ($ACTION_GARNISHMENT => writeReqGarnishmentAction, 
					   $ACTION_INFORM => writeReqInformAction,
					   $ACTION_RELEASE => writeReqReleaseAction,
					   $ACTION_ASSIGN_URG => writeReqAssign0Action,
					   $ACTION_ASSIGN_1_DAYS => writeReqAssign1Action,
					   $ACTION_ASSIGN_2_DAYS => writeReqAssign2Action,
					   $ACTION_ASSIGN_4_DAYS => writeReqAssign4Action);
$SELECT_ALL = "all";
$OUT_MODE_SCREEN = 1;
$OUT_MODE_FILE = 2;

@report_files = ();
%cameras = ();
%courts = ();
%banks = ();
%balances = ();
%exp_numbers = ();
%filters = ();
@input_files = ();
%results = ();

# Imprime las acciones ordenadas por dias de tardanza. No sirve para nada, lo guardo por las dudas
#foreach $n_days (sort keys %ACTIONS_BY_DAYS) {
#	print "$n_days - ";
#	foreach (@{$ACTIONS_BY_DAYS{$n_days}}) {
#		print "$_ ";
#	}
#	print "\n";
#}

sub scanForReportFiles {
	opendir(REPORTS_H, $REPODIR);
	foreach $file (readdir(REPORTS_H)) {
		# Filtro . y ..
		next if ($file =~ /^\.*$/);
		# No se agrega $EXP_OUT
		next if ($file eq $EXP_OUT);
		push(@report_files, $file) if (-f catfile($REPODIR,$file));
	}
	closedir(REPORTS_H);
}

sub printReportFiles {
	print "\nArchivos de informe disponibles:\n";
	my $c = 1;
	foreach $file (@report_files) {
		print "$c - $file\n";
		$c++;
	}
}

sub getReportsChoice {
	print "Elija los archivos a incluir como entrada de datos, ingresando uno o varios ".
		  "de los números separados por comas. Ingrese $SELECT_ALL si desea incluirlos ".
		  "todos o $EXP_OUT para usar el archivo exp_output.\nSelección: ";
	my (@selected) = split(",", <STDIN>);
	foreach (@selected) {
		chomp($_);
		$_ =~ s/^\s+|\s+$//g;
	}
	if ($selected[0] eq $SELECT_ALL) {
		push(@input_files, $SELECT_ALL);
	} elsif ($selected[0] eq $EXP_OUT) {
		push(@input_files, $EXP_OUT);
	} elsif ((scalar(@selected) == 1) && (! $selected[0])) {
		print "No ha ingresado nada.\n";
		getReportsChoice();
	} else {
		foreach $i (@selected) {
			if (($i < 1) || ($i > scalar(@report_files))) {
				print "No hay ningún archivo con el identificador $i\n";
				next;
			}
			push(@input_files, $report_files[$i-1]);
		}
	}
}

sub printMode {
	print "Modo elaboración de ";
	if ($mode == $MODE_REPORT) {
		print "informes\n";
	} else {
		print "pedidos\n";
	}
	print "\n";
}

sub printFilterOptionsHeader {
	print "\nDesea agregar algún filtro?\n".
		  "Los mismos se agregan de a uno por vez. Ingrese la categoría de filtro deseada, ".
		  "o $FILTER_NO_MORE para no agregar más.\n";
	print "Agregados hasta el momento: ".scalar(keys(%filters))."\n";
	print "Filtros disponibles:\n";
}

sub printFilterOption {
	my ($filter_key, $filter_name) = @_;
	print "$filter_key - Filtrar por $filter_name";
	if (exists $filters{$filter_key}) {
		print " (Ya agregado. $filter_name: ".join(" ", @{$filters{$filter_key}}).")";
	}
	print "\n";
}

sub printCommonFilterOptions {
	printFilterOptionsHeader();
	foreach $filter_id (keys(%COMMON_FILTERS)) {
		next if ($filter_id eq $BALANCE_ID);
		printFilterOption($filter_id, $COMMON_FILTERS{$filter_id});
	}
	my $filter_key = $BALANCE_ID;
	my $filter_name = $COMMON_FILTERS{$filter_key};
	print "$filter_key - Filtrar por $filter_name";
	if (exists $filters{$filter_key}) {
		my @filter_values = @{$filters{$filter_key}};
		#print "$filter_values[0] - $filter_values[1] - $filter_values[2]\n";
		print " (Ya agregado. $filter_name ".$BALANCE_RULES{$filter_values[0]}." ".$filter_values[1];
		print " ".$filter_values[1] if ($filter_values[0] == $BALANCE_RULE_BETWEEN);
		print ")";
	}
	print "\n";
}

sub printReqFilterOptions() {
	foreach $filter_id (keys(%REQUISITION_FILTERS)) {
		printFilterOption($filter_id, $REQUISITION_FILTERS{$filter_id});
	}
}

sub isValidFilter {
	my $filter_choice = @_[0];
	return ((exists($COMMON_FILTERS{$filter_choice})) ||
		   ($mode == $MODE_REQUISITION && exists($REQUISITION_FILTERS{$filter_choice})));
}

sub getFilterChoice {
	print "Ingrese la opción deseada: ";
	my $filter_choice = <STDIN>;
	chomp($filter_choice);
	while ((! isValidFilter($filter_choice)) && ($filter_choice ne $FILTER_NO_MORE)) {
		print "La opción ingresada no existe. Ingrésela nuevamente: ";
		$filter_choice = $filter_choice = <STDIN>;
		chomp($filter_choice);
	}
	return $filter_choice;
}

sub getFilterValues {
	my $filter_choice = @_[0];
	my $filter_sub = $FILTER_VALUES_SUBS{$filter_choice};
	&{$filter_sub}($filter_choice) if (defined($filter_sub));
}

sub printFilterValuesHeader {
	my $filter_name = @_[0];
	print "Elija los que desea incluir al procesar los datos, ingresando uno o varios ".
		  "separados por comas. Ingrese $SELECT_ALL si no desea excluir ninguno. ";
}

sub readFilterValues {
	my $filter_choice = @_[0];
	my (@selected) = split(",", <STDIN>);
	my $index = 0;
	while ($index <= $#selected) {
		chomp($selected[$index]);
		$selected[$index] =~ s/^\s+|\s+$//g;
		if ($selected[$index] eq "") {
			splice(@selected, $index, 1);
		} else {
			$index++;
		}
	}
	if ($selected[0] eq $SELECT_ALL) {
		$filters{$filter_choice} = [$SELECT_ALL];
	} elsif (scalar(@selected) == 0) {
		print "No ha ingresado nada. Ingrese uno o varios separados por comas. Ingrese ".
			  "$SELECT_ALL si no desea excluir ninguno.\nSelección: ";
		readFilterValues($filter_choice);
	} else {
		$filters{$filter_choice} = [@{dclone(\@selected)}];
	}
}

sub getCamerasFilterValues {
	my $filter_choice = @_[0];
	print "Elija Cámaras a incluir al procesar los datos, ingresando una o varias ".
		  "separadas por comas. Ingrese $SELECT_ALL si no desea excluir ninguna.\n";
	print "Cámaras disponibles:\n";
	my $id = 1;
	foreach (sort(keys(%cameras))) {
		print "$id - $_\n";
		$id++;
	}
	print "Ingrese la/las deseadas por el número (primer columna), o $SELECT_ALL para ".
		  "no excluir ninguna: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el estado correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my @ordered_cameras = sort(keys(%cameras));
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 1) || ($id > scalar(@ordered_cameras))) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $ordered_cameras[$id-1]);
			$index++;
		}
	}
}

sub getCourtsFilterValues {
	my $filter_choice = @_[0];
	printFilterValuesHeader($filter_choice);
	print "Tribunales disponibles:\n";
	my $id = 1;
	foreach (sort(keys(%courts))) {
		my ($desc_1, $desc_2) = @{$courts{$_}};
		print "$id - $desc_1";
		print ", $desc_2" if($desc_2 ne "");
		print "\n";
		$id++;
	}
	print "Ingrese el/los deseados por id (primer columna), o $SELECT_ALL para ".
		  "no excluir ninguno: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el estado correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my @ordered_courts = sort(keys(%courts));
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 1) || ($id > scalar(@ordered_courts))) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $ordered_courts[$id-1]);
			$index++;
		}
	}
}

sub getExpFilterValues {
	my $filter_choice = @_[0];
	printFilterValuesHeader($filter_choice);
	print "Expedientes disponibles:\n";
	my $id = 1;
	foreach (@exp_numbers) {
		print "$id - $_\n";
		$id++;
	}
	print "Ingrese el/los deseados, o $SELECT_ALL para no excluir ninguno: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el expediente correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 1) || ($id > scalar(@exp_numbers))) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $exp_numbers[$id-1]);
			$index++;
		}
	}
}

sub getStateFilterValues {
	my $filter_choice = @_[0];
	printFilterValuesHeader($filter_choice);
	print "Estados disponibles:\n";
	my $id = 1;
	foreach (@STATES) {
		print "$id - $_\n";
		$id++;
	}
	print "Ingrese el/los deseados por el número (primer columna), o $SELECT_ALL para ".
		  "no excluir ninguno: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el estado correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 1) || ($id > scalar(@STATES))) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $STATES[$id-1]);
			$index++;
		}
	}
}

sub getBalanceOptions {
	print "\nElija una de las siguientes opciones de filtrado:\n";
	print "$BALANCE_RULE_NONE - Cuentas $BALANCE_RULES{$BALANCE_RULE_NONE}\n";
	print "$BALANCE_RULE_LESSER - Cuentas con saldo $BALANCE_RULES{$BALANCE_RULE_LESSER} que un valor\n";
	print "$BALANCE_RULE_GREATER - Cuentas con saldo $BALANCE_RULES{$BALANCE_RULE_GREATER} que un valor\n";
	print "$BALANCE_RULE_BETWEEN - Cuentas con saldo $BALANCE_RULES{$BALANCE_RULE_BETWEEN} valores\n";
	print "Selección: ";
	my $rule = <STDIN>;
	chomp($rule);
	return $rule;
}

sub getBalanceValue {
	my $rule = @_[0];
	print "Se filtraran saldos con valor ".$BALANCE_RULES{$rule}." a: ";
	my $value = <STDIN>;
	chomp($value);
	if ($value !~ /^-?\d+$/) {
		print "Entrada incorrecta, debe ingresar un número.\n";
		getBalanceValue($rule);
	}
	push(@{$filters{$BALANCE_ID}}, $value);
}

sub getBalanceValues {
	getBalanceValue($BALANCE_RULE_LESSER);
	getBalanceValue($BALANCE_RULE_GREATER);	
}

sub getBalanceFilterValues {
	my $filter_choice = @_[0];
	my $rule = getBalanceOptions();
	while (($rule < $BALANCE_RULE_NONE) || ($rule > $BALANCE_RULE_BETWEEN)) {
		print "La opción elegida es incorrecta\n";
		$rule = getBalanceOptions();
	}
	$filters{$filter_choice} = [$rule];
	return if ($rule == $BALANCE_RULE_NONE);
	if ($rule == $BALANCE_RULE_BETWEEN) {
		getBalanceValues();
	} else {
		getBalanceValue($rule);
	}
}

sub getTypeFilterValues {
	my $filter_choice = @_[0];
	printFilterValuesHeader($filter_choice);
	print "Tipos de pedido disponibles:\n";
	my $id = 1;
	foreach (sort(keys(%ACTIONS_BY_TYPE))) {
		print "$id - $_\n";
		$id++;
	}
	print "Ingrese el/los deseados por el número (primer columna), o $SELECT_ALL para ".
		  "no excluir ninguno: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el tipo correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my @ordered_types = sort(keys(%ACTIONS_BY_TYPE));
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 1) || ($id > scalar(@ordered_types))) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $ordered_types[$id-1]);
			$index++;
		}
	}
}

sub getUrgencyFilterValues {
	my $filter_choice = @_[0];
	printFilterValuesHeader($filter_choice);
	print "Niveles de urgencia disponibles:\n";
	foreach (sort(keys(%ACTIONS_BY_DAYS))) {
		print "$_ - $_ días\n";
	}
	print "Ingrese el/los deseados por el número (primer columna), o $SELECT_ALL para ".
		  "no excluir ninguno: ";
	readFilterValues($filter_choice);
	return if($filters{$filter_choice}[0] eq $SELECT_ALL);
	# Reemplaza los valores de id leidos por el tipo correspondiente, y filtra los incorrectos
	my $choices_ref = $filters{$filter_choice};
	my @ordered_days = sort(keys(%ACTIONS_BY_DAYS));
	my $index = 0;
	while ($index <= $#{$choices_ref}) {
		my $id = ${$choices_ref}[$index];
		if (($id < 0) || ($id > $#ordered_days)) {
			splice(@{$choices_ref}, $index, 1);
		} else {
			splice(@{$choices_ref}, $index, 1, $ordered_days[$id]);
			$index++;
		}
	}
}

sub processFile {
	my $file = @_[0];
	my @data;
	open(my $FH, catfile($REPODIR, $file)) || die "Error al abrir el archivo $file\n";
	while (<$FH>) {
		chomp $_;
		next if ($_ == "");
		@data = split(";", $_);
		next if(scalar(@data) < $FIELDS_COUNT);
		my $filtered = 0;
		foreach $filter (keys(%filters)) {
			next if (${$filters{$filter}}[0] eq $SELECT_ALL);
			$filtered = $FILTER_PROCESS_SUBS{$filter}(@data);
			last if ($filtered);
		}
		if (! $filtered) {
			$results{$data[0]} = [@{dclone(\@data)}] if (! exists($results{$data[0]}));
		}
	}
}

sub processCamerasFiltering {
	my (@file_data) = @_;
	foreach $camera (@{$filters{$CAMERA_ID}}) {
		if ($file_data[$CAMERA_POSITION] eq $camera) {
			return 0;
		}
	}
	return 1;
}

sub processCourtsFiltering {
	my (@file_data) = @_;
	foreach $court (@{$filters{$COURT_ID}}) {
		if ($file_data[$COURT_POSITION] eq $court) {
			return 0;
		}
	}
	return 1;
}

sub processExpFiltering {
	my (@file_data) = @_;
	foreach $exp (@{$filters{$EXP_ID}}) {
		if ($file_data[$EXP_POSITION] eq $exp) {
			return 0;
		}
	}
	return 1;
}

sub processStateFiltering {
	my (@file_data) = @_;
	foreach $state (@{$filters{$STATE_ID}}) {
		if ($file_data[$STATE_POSITION] eq $state) {
			return 0;
		}
	}
	return 1;
}

sub processBalanceFiltering {
	my (@file_data) = @_;
	my $rule = ${$filters{$BALANCE_ID}}[0];
	$BALANCE_FILTER_SUBS{$rule}(@file_data);
}

sub processBalanceNone {
	my (@file_data) = @_;
	return 0 if ($file_data[$BALANCE_POSIOTION] == "");
	return 1;
}

sub processBalanceLesser {
	my (@file_data) = @_;
	my $limit = ${$filters{$BALANCE_ID}}[1];
	my $balance = $file_data[$BALANCE_POSIOTION];
	return 0 if (($balance != "") && ($balance < $limit));
	return 1;
}

sub processBalanceGreater {
	my (@file_data) = @_;
	my $limit = ${$filters{$BALANCE_ID}}[1];
	my $balance = $file_data[$BALANCE_POSIOTION];
	return 0 if (($balance != "") && ($balance > $limit));
	return 1;
}

sub processBalanceBetween {
	my (@file_data) = @_;
	my $limit_lesser = ${$filters{$BALANCE_ID}}[1];
	my $limit_greater = ${$filters{$BALANCE_ID}}[2];
	my $balance = $file_data[$BALANCE_POSIOTION];
	return 0 if (($balance != "") &&
                 ($balance < $limit_lesser) && 
                 ($balance > $limit_greater));
	return 1;
}

sub processTypeFiltering {
	my (@file_data) = @_;
	foreach $type (@{$filters{$TYPE_ID}}) {
		foreach $action (@{$ACTIONS_BY_TYPE{$type}}) {
            if ($file_data[$ACTION_POSITION] eq $action) {
                return 0;
            }
        }
	}
	return 1;
}

sub processUrgencyFiltering {
	my (@file_data) = @_;
	foreach $days (@{$filters{$URGENCY_ID}}) {
		foreach $action (@{$ACTIONS_BY_DAYS{$days}}) {
            if ($file_data[$ACTION_POSITION] eq $action) {
                return 0;
            }
        }
	}
	return 1;
}

sub getOutputMode {
	print "\nElija si desea mostrar los resultados por pantalla o grabarlos en un ".
	"archivo.\n$OUT_MODE_SCREEN- Mostrar por pantalla\n$OUT_MODE_FILE- Grabar en ".
	"archivo\nSelección: ";
	my $output_mode = <STDIN>;
	while (($output_mode != $OUT_MODE_SCREEN) && ($output_mode != $OUT_MODE_FILE)) {
		print "No ha elejido una opción correcta. Las mismas son:\n$OUT_MODE_SCREEN- ".
		"Mostrar por pantalla\n$OUT_MODE_FILE- Grabar en archivo\nReingrese: ";
		$output_mode = <STDIN>;
	}
	return $output_mode;
}

sub getOutputFileName {
	print "Ingrese el nombre del archivo donde se guardará el pedido: ";
	my $file_name = <STDIN>;
	while (! $file_name =~ /^[\w\.-]+$/) {
		print "$file_name no es un nombre válido. Solo puede contener letras (mayúsculas o ".
			  "minúsculas), números, guiones bajo, guiones medio y puntos. Reingrese: ";
		my $file_name = <STDIN>;
	}
	chomp($file_name);
	return $file_name;
}

sub writeResults {
	if (scalar(keys(%results)) == 0) {
		print $output_handler "No hay resultados para la consulta\n";
	}
	foreach $key (sort(keys(%results))) {
		my @data = @{$results{$key}};
		writeDataToOutput(@data);
	}
}

sub writeDataToOutput {
	my @data = @_;
	if ($mode == $MODE_REPORT) {
		writeReportModeData(@data);
	} else {
		writeRequisitionModeData(@data);
	}
}

sub writeReportModeHeader {
	print $output_handler "Filtros: ";
	if (scalar(%filters) == 0) {
		print $output_handler "No se seleccionaron filtros\n";
		return;
	}
	foreach $filter_key (keys(%filters)) {
		my $filter_name = $COMMON_FILTERS{$filter_key};
		$filter_name = $REQUISITION_FILTERS{$filter_key} if ((! $filter_name) && ($mode == $MODE_REQUISITION));
		print $output_handler "$filter_name ";
		foreach $value (@{$filters{$filter_key}}) {
			print $output_handler "$value ";
		}
	}
	print $output_handler "\n";
}

sub writeReportModeData {
	my @data = @_;
	print $output_handler join(";", @data)."\n";
}

sub writeRequisitionModeData {
	my @data = @_;
	my $action = $data[$ACTION_POSITION];
	writeReqModeCommon(@data);
	$ACTION_OUTPUT_SUBS{$action}(@data);
}

sub writeReqModeCommon {
	my ($exp, $camera, $court, $cover, $state, $cbu, $balance, $action) = @_;
	print $output_handler "Cámara: ($camera) ".$cameras{$camera}[0]." Tribunal: ($court) ".$courts{$court}[0];
	print $output_handler " ".$courts{$court}[1] if (scalar($courts{$court}) > 1);
	print $output_handler " Oficina de Remisión: Mesa de Entradas\n";
	print $output_handler "Expediente: $exp Carátula: $cover\n";
}

sub writeReqGarnishmentAction {
	my ($exp, $camera, $court, $cover, $state, $cbu, $balance, $action) = @_;
	my($day, $month, $year)=(localtime)[3,4,5];
	print $output_handler "Tema: Pedido de Embargo sobre cuenta bancaria Fecha de Origen: ".
		  "$day/".($month+1)."/".($year+1900)." Fojas: 1\n";
	print $output_handler "Extracto: solicítese en carácter de URGENTE la tramitación de embargo ".
		  "sobre la cuenta bancaria asignada en fojas precedentes: CBU Nro: $cbu\n";
}

sub writeReqInformAction {
	my ($exp, $camera, $court, $cover, $state, $cbu, $balance, $action) = @_;
	my ($bank_id) = $balances{$cbu}[0];
	my($day, $month, $year) = (localtime(time + 2*86400))[3,4,5]; # Se suman dos dias
	print $output_handler "Tema: Pedido de Información de saldo sobre cuenta bancaria ".
		  "Fecha de Origen: $day/".($month+1)."/".($year+1900)." Fojas: 1\n";
	print $output_handler "Extracto: Solicítese a la Entidad Bancaria $bank_id ".
		  $banks{$bank_id}[1]." que informe diariamente el saldo de la cuenta bancaria ".
		  "asignada en fojas precedentes CBU Nro: $cbu\n";
}

sub writeReqReleaseAction {
	my ($exp, $camera, $court, $cover, $state, $cbu, $balance, $action) = @_;
	my($day, $month, $year)=(localtime)[3,4,5];
	print $output_handler "Tema: Pedido de Liberación de Embargo sobre cuenta bancaria ".
		  "Fecha de Origen: $day/".($month+1)."/".($year+1900)." Fojas: 1\n";
	print $output_handler "Extracto: solicítese en carácter de URGENTE la tramitación ".
		  "de liberación de embargo sobre la cuenta bancaria asignada en fojas ".
		  "precedentes: CBU Nro: $cbu\n";
}

sub writeReqAssign0Action {
	my ($exp, $camera, $court, $cover, $state, $cbu, $balance, $action) = @_;
	my($day, $month, $year)=(localtime)[3,4,5];
	print $output_handler "Tema: Pedido de Asignación de Cuenta Bancaria Fecha de ".
		  "Origen: $day/".($month+1)."/".($year+1900)." Fojas: 1\n";
	print $output_handler "Extracto: solicítese en carácter de URGENTE la Asignación de una ".
		  "NUEVA cuenta bancaria dado que la asignada en fojas precedentes es inválida: $cbu\n";
}

sub writeReqAssign1Action {
	writeReqAssignCommon(1);
}

sub writeReqAssign2Action {
	writeReqAssignCommon(2);
}

sub writeReqAssign4Action {
	writeReqAssignCommon(4);
}

sub writeReqAssignCommon {
	my $n = @_[0];
	my($day, $month, $year) = (localtime(time + $n*86400))[3,4,5]; # Se suman n dias
	print $output_handler "Tema: Pedido de Asignación de Cuenta Bancaria Fecha de Origen: ".
	"$day/".($month+1)."/".($year+1900)." Fojas: 1\n";
	print $output_handler "Extracto: Reitérese solicitud de asignación de cuenta bancaria ".
		  "a través de su Clave Bancaria Uniforme (CBU) y pedido de informe diario de saldo ".
		  "sobre dicha cuenta a la entidad bancaria correspondiente.\n";
}

sub getFileDataByID {
	my ($query_id, $id_field, $file) = @_;
	my (@data) = ();
	open(my $FH, $file) || die "Error al abrir el archivo $file\n";
	while (<$FH>) {
		chomp $_;
		@data = split(";", $_);
		last if ($data[$id_field] eq $query_id);
	}
	if ($data[$id_field] ne $query_id) {
		$data[$id_field] = undef;
	}
	close($FH);
	return @data;
}	

sub getCameraDescriptionByID {
	my ($query_id) = @_[0];
	my ($ID_FIELD) = 0;
	my ($camera_id, $camera_description) = getFileDataByID($query_id, $ID_FIELD, catfile($MAEDIR, $MAE_CAMERAS));
	return "Cámara $query_id no encontrada" if (! defined $camera_id);
	return $camera_description;
}

sub getCourtDescriptionByID {
	my ($query_id) = @_[0];
	my ($ID_FIELD) = 0;
	my ($court_id, $court_description_1, $court_description_2) = getFileDataByID($query_id, $ID_FIELD, catfile($MAEDIR, $MAE_COURTS));
	return ("Tribunal $query_id no encontrado", "") if (! defined $court_id);
	return ($court_description_1, $court_description_2);
}

sub getExpInfoByID {
	my ($query_id) = @_[0];
	my ($ID_FIELD) = 0;
	my (@data) = getFileDataByID($query_id, $ID_FIELD, catfile($MAEDIR, $MAE_COURTS));
	return (undef, "Expediente $query_id no encontrado") if (! defined $data[ID_FIELD]);
	return @data;
}

sub getFileDataByValue {
	# TODO No se si va a ser util
	my ($query_value, $value_field, $filter_sub_ref, $file, $ret_list_ref, $extra_value) = @_;
	my (@data) = ();
	open(my $FH, $file) || die "Error al abrir el archivo $file\n";
	while (<$FH>) {
		chomp $_;
		@data = split(";", $_);
		push(@{$ret_list_ref}, [@{dclone(\@data)}]) if ($filter_sub_ref->($query_value, $data[$value_field], $extra_value));
	}
	close($FH);
}

sub filterByStateSub {
	#TODO No se si va a ser necesario
	my ($query_value, $data_value, $extra_value) = @_;
	return ($query_value eq $data_value);
}

sub getExpInfoByState {
	#TODO No se si va a ser necesario. Falta terminar
	my ($query_id) = @_[0];
	my $ID_FIELD = 4;
}

sub readToHashByID {
	my ($file, $data_hash_ref, $ID_FIELD) = @_;
	my (@data) = ();
	open(my $FH, $file) || return -1;
	while (<$FH>) {
		chomp $_;
		@data = split(";", $_);
		my $index = 0;
		while ($index <= $#data) {
			chomp($data[$index]);
			$data[$index] =~ s/^\s+|\s+$//g;
			if ($data[$index] eq $FIELD_NO_DATA) {
				splice(@data, $index, 1);
			} else {
				$index++;
			}
		}
		$data_hash_ref->{$data[$ID_FIELD]} = [@{dclone(\@data)}];
		splice(@{$data_hash_ref->{$data[$ID_FIELD]}}, $ID_FIELD, 1);
	}
	close($FH);
	return 0;
}

sub setUpCamerasHash {
	my $ID_FIELD = 0;
	return readToHashByID(catfile($MAEDIR, $MAE_CAMERAS), \%cameras, $ID_FIELD);
}

sub setUpCourtsHash {
	my $ID_FIELD = 0;
	return readToHashByID(catfile($MAEDIR, $MAE_COURTS), \%courts, $ID_FIELD);
}

sub setUpBanksHash {
	my $ID_FIELD = 1;
	my $ret = readToHashByID(catfile($MAEDIR, $MAE_BANKS), \%banks, $ID_FIELD);
	# Se borran los ultimos 3 campos que no se utilizan nunca
	foreach (keys(%banks)) {
		splice(@{$banks{$_}}, 2, 3); # Va 2 porque ya se elmino un campo, quedan 5
	}
	return $ret;
}

sub setUpBalancesHash {
	my $ID_FIELD = 2;
	my $ret = readToHashByID(catfile($MAEDIR, $BALANCES_SUBDIR, $MAE_BALANCES), \%balances, $ID_FIELD);
	# Se borra el primer campo que no se utiliza nunca
	foreach (keys(%balances)) {
		splice(@{$balances{$_}}, 0, 1);
	}
	return $ret;
}

sub setUpExpList {
	my (@data) = ();
	open(my $FH, catfile($REPODIR, $EXP_OUT)) || return -1;
	while (<$FH>) {
		chomp $_;
		@data = split(";", $_);
		$data[$EXP_POSITION] =~ s/^\s+|\s+$//g;
		push(@exp_numbers, $data[$EXP_POSITION]);
	}
	close($FH);
}

sub printHelp {
	print "\nAyuda del programa Liste\n\n";
	print "El programa Liste se encarga de elaborar informes y pedidos, en base a ".
          "los datos recopilados por el sistema Dossiere.\n";
    print "Se ejecuta desde la línea de comandos como\n\n\t./Liste.pl\n\n";
    print "Hay 2 modos de trabajo: elaboración de informes y eleaboración de pedidos. ".
          "En ambos modos se pueden usar diferentes filtros al hacer consultas sobre ".
          "los datos. Los mismos son:\n\n";
    print "Cámara: Permite elegir mostrar resultados que contengan una, varias o todas las cámaras\n";
    print "Tribunal: Permite elegir mostrar resultados que contengan uno, varios o todos los tribunales\n";
    print "Expediente: Permite elegir mostrar resultados que contengan uno, varios o todos los expedientes\n";
    print "Estado informado: Permite elegir mostrar resultados que contengan uno, varios o todos los estados\n";
    print "Saldo: Permite elegir mostrar resultados que no contengan saldo, tengan un saldo mayor o menor ".
          "un número, o que tengas un saldo entre dos números\n";
    print "Tipo de pedido: Solo disponible en el modo pedido. Permite elegir mostrar resultados que sean ".
          "de un solo tipo, de varios tipos o de todos los tipos de pedidos\n";
    print "Nivel de urgencia: Solo disponible en el modo pedido. Permite elegir mostrar los resultados por ".
           "un nivel de urgencia, varios niveles, o todos los niveles de urgencia.\n\n";
    print "Los resultados pueden mostrarse por pantalla o grabarse a un archivo.\n";
    print "En el modo de eleaboración de informes se toman los datos del archivo exp_output, generado por ".
          "Cdossier, y se muestran en el mismo formato. Si se graban a un archivo, el mismo se puede usar ".
          "como entrada para el modo de elaboración de pedidos.\n";
    print "En el modo de elaboración de pedidos se elaboran los pedidos a la justicia federal, en base a los ".
          "datos del archivo exp_output, o de uno o varios de los archivos de informe generados por este ".
          "mismo programa. Cada pedido se muestra con un formato predeterminado, dependiendo del tipo de pedido ".
          "y la acción a efectuar.\n\n";
}

##################################### MAIN #####################################

# Chequea si se inicializo el ambiente
die "No se realizó la inicialización de ambiente\n" if ($INITIALIZED != 1);
# Chequea si el proceso ya esta ejecutandose
($process_name) = ($0 =~ /\/?(.+)$/);
die "Liste ya está ejecutándose\n" if (`ps -C $process_name -o pid=`);

# Inicializa report_files con los reportes que encuentra en el directorio
scanForReportFiles();
# Carga los datos de camaras, tribunales y bancos en los hash correspondientes
setUpCamerasHash();
setUpCourtsHash();
setUpBanksHash();
setUpBalancesHash();
setUpExpList();

#foreach $key (keys(%balances)) {
#	$s = join(",", @{$balances{$key}});
#	print "$key - $s\n";
#}
#exit 0;

# Eleccion de modo informe o modo pedido
do {
	print "\nDeséa elaborar informes o pedidos?\n\n$MODE_REPORT- Informes\n$MODE_REQUISITION- Pedidos\n$MODE_HELP- Ayuda\n$MODE_EXIT- Salir\n\nOpción elegida: ";
	$mode = <STDIN>;
} while ($mode != $MODE_REPORT && 
		 $mode != $MODE_REQUISITION && 
		 $mode != $MODE_HELP &&
		 $mode != $MODE_EXIT);

if ($mode == $MODE_HELP) {
	printHelp();
	exit 0;
}		 

while ($mode != $MODE_EXIT) {
	print "\n";
	printMode();

	# Filtros
	%filters = ();
	do {
		printCommonFilterOptions();
		# Filtros adicionales del modo pedidos
		if ($mode == $MODE_REQUISITION) {
			printReqFilterOptions();
		}
		print "$FILTER_NO_MORE - No seleccionar más filtros\n";
		$filter_choice = getFilterChoice();
		getFilterValues($filter_choice);
	} while ($filter_choice ne $FILTER_NO_MORE);

	# Archivos de entrada
	@input_files = ();
	if ($mode == $MODE_REQUISITION) {
		if (scalar(@report_files) > 0) {
			printReportFiles();
			getReportsChoice();
		}
		if (scalar(@input_files) < 1) {
			push(@input_files, $EXP_OUT);
			print "No se encontraron arhcivos de informes. Se usará el archivo $EXP_OUT ".
				  "completo como entrada.\nPresione <enter> para continuar...";
			<STDIN>;
		}
	} else {
		push(@input_files, $EXP_OUT);
	}
	
	# Seleccion de salida de los resultados
	$output_mode = getOutputMode();
	if ($output_mode == $OUT_MODE_FILE) {
		$output_file_name = getOutputFileName();
		open($output_handler, ">".catfile($REPODIR, $output_file_name));
	} else {
		$output_handler = STDOUT;
	}
	print "\n";
	
	# Procesamiento de datos
	%results = ();
	foreach $file (@input_files) {
		processFile($file);
	}
	
	# Impresion de resultados
	# Se escribe el header del modo informe
	if ($mode == $MODE_REPORT) {
		writeReportModeHeader();
	}
	writeResults();
	
	close($output_handler) if ($output_mode == $OUT_MODE_FILE);
	
	print "\n\nDesea realizar otra consulta? Ingrese s para realizar otra, n para salir: ";
	$continue = <STDIN>;
	chomp($continue);
	$mode = $MODE_EXIT if ($continue ne "s");
}

exit 0;
