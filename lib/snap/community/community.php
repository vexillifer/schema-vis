<?php

if(isset($_POST['edges'])) {
    $edges = $_POST['edges'];

    $hash = md5($edges);
    $cached_file = "cache/comm_output_".$hash.".txt";
    $fh = null;

    // check for cached solution
    if(file_exists($cached_file)) {

        $fh = fopen($cached_file, 'r');
    } else {

        // write edges to graph format and run SNAP community detection
        // NOTE: we need write permissinos on comm_input and comm_output
        // otherwise we get really annoying and hard to find errors.

        $comm_input = "comm_input.txt";
        $comm_output = "comm_output.txt";
        $fh = fopen($comm_input, 'w');
        fwrite($fh, $edges);
        fclose($fh);
        $output = array();
        $return_val = null;
        exec("./community -i:$comm_input -o:$comm_output -a:1 2>&1", $output, $return_val);

        // cache the result
        copy($comm_output, $cached_file);

        // Load output and parse results
        $fh = fopen($comm_output, 'r');
    }


    $cluster = array();
    $clusters = array();
    $cluster_num = 0;

    // Create an array of clusters (an array of node indices)
    while (!feof($fh)) {
        $line = fgets($fh);
        // Filter out meta data
        if (preg_match("/#/", $line) === 0) {
            $parts = preg_split('/\s/', $line);
            if (count($parts) > 1 && $parts[1] === strval($cluster_num)) {
                $cluster[] = $parts[0];
            } else {
                // begin next cluster
                $clusters[] = $cluster;
                $cluster = array();
                $cluster_num++;
                $cluster[] = $parts[0];
            }
        }
    }

    // Formatting to [[],[],[]]
    $cluster_str = '';
    foreach($clusters as $cluster) {
        $cluster_str .= '[' . implode(",", $cluster) . '],';
    }
    $cluster_str = '[' . rtrim($cluster_str, ',') . ']';

    fclose($fh);
    echo $cluster_str;

} else {
    // no edges passed, no clusters returned
    echo "[]";
}
?>