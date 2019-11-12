<?php

//variables to update

//$input = full path to text file containing one PID per line: namespace:ID
$input = '/home/kristina/code/islandora-data-tools/data/pids.txt';

//$output = full path to directory in which you'd like output written
$output = '/home/kristina/code/islandora-data-tools/data';


drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$idlist = fopen($input, 'r');
$outfile = fopen("{$output}/tn_size.txt", 'a');

if ($idlist) {
    while (($line = fgets($idlist)) !== false) {
        $pid = rtrim($line);
        $tn = get_tn_size($pid);
        fwrite($outfile, "{$pid}\t{$tn}\n");
    }
}

function get_tn_size($pid)
{
    $obj = islandora_object_load($pid);
    $tnds = $obj['TN'];
    if (empty($tnds)) {
        return 'empty';
    } else {
        return $tnds->size;
    }
}


?>
