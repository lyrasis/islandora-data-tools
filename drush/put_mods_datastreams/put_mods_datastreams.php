<?php

// // // VARIABLES TO SET
$modsdir = '/opt/migrations/ns/coll/mods-current';
// // // END OF VARIABLES TO SET

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$modslist = scandir($modsdir);

foreach ($modslist as $mods) {
    if (stripos($mods, '.xml') !== false) {
        $path = $modsdir . '/' . $mods;

        $pid = str_replace('.xml', '', $mods);

        $obj = islandora_object_load($pid);
        $mds = $obj['MODS'];
        $mds->setContentFromFile($path);
        print 'Put ' . $path . "\n";
    }
}

?>
