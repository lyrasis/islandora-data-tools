<?php

// // // VARIABLES TO SET
$tndir = '/opt/migrations/project/coll/thumbnails';
$suffixes = ['.jpg', '.png'];
// // // END OF VARIABLES TO SET

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$tnlist = scandir($tndir);
$tnfiles = [];

foreach ($tnlist as $tn) {
    if (!in_array(trim($tn), ['.', '..'])) {
        $tnfiles[] = $tn;
    }
}

foreach ($tnfiles as $tn) {
    $path = $tndir . '/' . $tn;

    $pid = $tn;
    foreach ($suffixes as $suffix) {
        $pid = str_replace($suffix, '', $pid);        
    }
    $pid = str_replace('-', ':', $pid);

    $obj = islandora_object_load($pid);
    $tnds = $obj['TN'];
    $tnds->setContentFromFile($path);
    print 'Put ' . $path . "\n";
}

?>
