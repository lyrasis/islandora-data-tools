<?php

//Store the micro time so that we know
//when our script started to run.
$executionStartTime = microtime(true);

drupal_static_reset('islandora_get_tuque_connection');
$tuque = islandora_get_tuque_connection();
$repository = $tuque->repository;

$api_a = $repository->api->a; // For an Access API.
$repository_info = $api_a->describeRepository();

// DREW: this isn't bringing up anything, but that may just be that the 'repositoryPIDNamespace' field is empty.
// When I try printing the field, it doesn't print anything but it also doesn't throw an error.
$savedir = '/opt/migrations/reports/'.$repository_info['repositoryPIDNamespace'];

if(!is_dir($savedir)) {
  mkdir($savedir,0777,true);
}

generate_report();

//At the end of your code, compare the current
//microtime to the microtime that we stored
//at the beginning of the script.
$executionEndTime = microtime(true);

//The result will be in seconds and milliseconds.
$seconds = $executionEndTime - $executionStartTime;

$message = "\n\nThis script took $seconds to execute.";

//Print it out
echo $message;

function generate_report()
{
  $query = <<<QUERY
  select distinct ?coll ?type
  from <#ri>
  where {
    ?coll <fedora-model:hasModel> <info:fedora/islandora:collectionCModel>.
    ?gen <fedora-rels-ext:isMemberOfCollection> ?coll;
      <fedora-model:hasModel> ?type.
  } 
  order by ?coll
QUERY;

// DREW: calling the sparqlQuery method results in the following error:
// `Error: Call to a member function sparqlQuery() on null in generate_report()`
  $results = $repository->ri->sparqlQuery($query);

  $fp = fopen($savedir.'report_coll_children.csv', 'w');

  foreach ($results as $result) {
    fputcsv(array($result['coll']['value'], $result['type']['value']));
  }

  fclose($fp);
}

?>
