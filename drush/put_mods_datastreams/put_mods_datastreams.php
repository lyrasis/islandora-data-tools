<?php

// // // VARIABLES TO SET
$modsdir = '/opt/migrations/client/dir_containing_mods';
// // // END OF VARIABLES TO SET

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$modslist = scandir($modsdir);
$modscount = count($modslist);
$counter = 0;

foreach ($modslist as $mods) {
    if (stripos($mods, '.xml') !== false) {
        $path = $modsdir . '/' . $mods;

        $pid = str_replace('.xml', '', $mods);
        $pid = str_replace('-', ':', $pid);
        
        $obj = islandora_object_load($pid);
        $mds = $obj['MODS'];
        $mds->setContentFromFile($path);
        $counter = ++$counter;
        echo progress_bar($counter, $modscount, 'MODS Replacement Status');
    }
}

function progress_bar($done, $total, $info="", $width=50) {
    $perc = round(($done * 100) / $total);
    $bar = round(($width * $perc) / 100);
    return sprintf("%s%%[%s>%s]%s\r", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}
?>
