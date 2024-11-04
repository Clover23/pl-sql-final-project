
BEGIN
    log_util.log_start(p_proc_name => 'test1', p_text => 'hello');
    log_util.log_error(p_proc_name => 'test1',p_sqlerrm => 'ERR_MESSAGE', p_text => 'smth happened');
    log_util.log_finish(p_proc_name => 'test1', p_text => 'bye');
END;