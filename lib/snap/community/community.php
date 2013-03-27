<?php

if(isset($_POST['edges'])) {

    // write edges to graph format and run SNAP community detection
    $comm_input = "comm_input.txt";
    $fh = fopen($comm_input, 'w');
    fwrite($fh, $edges);
    fclose($fh);

    exec("./community -i:comm_input.txt -o:comm_output.txt -a:1");

    // Load output and parse results
    $comm_output = "comm_output.txt";
    $fh = fopen($comm_output, 'r');

    $cluster = array();
    $clusters = array();
    $cluster_num = 0;

    // Create an array of clusters (an array of node indices)
    while (!feof($fh)) {
        $line = fgets($fh);
        // Filter out meta data
        if (preg_match("/#/", $line) === 0) {
            $parts = preg_split('/\s/', $line);
            if ($parts[1] === strval($cluster_num)) {
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