var stdout_buffer = "";

function stdout(msg)
{
    // if(! debugging) {
    //     return;
    // }

    var lines = (stdout_buffer + msg).split('\n');
    for (var i = 0; i < lines.length-1; i++)
    {
        print(lines[i]);
    }
    stdout_buffer = lines[lines.length-1];
}

function predicate_flush_stdout()
{
    if (stdout_buffer !== "")
        stdout("\n");
    return true;
}

function alert(msg) {
    print('alert:' + msg);
}
