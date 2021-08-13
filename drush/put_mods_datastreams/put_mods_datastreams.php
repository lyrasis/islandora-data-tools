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
        $counter = ++$counter;
        echo progress_bar($counter, $modscount, 'MODS Replacement Status');

        $path = $modsdir . '/' . $mods;

        $pid = str_replace('.xml', '', $mods);
        $pid = str_replace('-', ':', $pid);

        $obj = islandora_object_load($pid);
	if (!$obj) {
	  drush_log(dt("Nonexistent object: !pid -- MODS not replaced",
            array('!pid' => $pid)),
            'warning');
	  continue;
	}

        $mds = $obj['MODS'];
	if (!$mds) {
	  drush_log(dt("Nonexistent MODS datastream for !pid -- MODS not replaced",
            array('!pid' => $pid)),
            'warning');
	  continue;
	}

        $mds->setContentFromFile($path);
	drush_log(dt("MODS datastream replaced for !pid -- MODS",
            array('!pid' => $pid)),
            'info');
    }
}

function progress_bar($done, $total, $info="", $width=50) {
    $perc = round(($done * 100) / $total);
    $bar = round(($width * $perc) / 100);
    return sprintf("%s%%[%s>%s]%s\r", $perc, str_repeat("=", $bar), str_repeat(" ", $width-$bar), $info);
}
?>
