# Единственный аргумент: путь к проекту .xpr.
if {[catch {
    if {[llength $argv] != 1} {
        error "Укажите единственный аргумент: <проект.xpr>"
    }
    set project_file [file normalize [lindex $argv 0]]
    open_project $project_file
    # Сбрасываем результаты проекта, включая отдельные runs IP.
    reset_project
    # В чистом checkout сначала создаём продукты IP и runs их вложенных ядер.
    set ips [get_ips -quiet]
    if {[llength $ips]} {
        generate_target all $ips
        foreach ip $ips { create_ip_run $ip }
    }
    update_compile_order -fileset sources_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property STATUS [get_runs synth_1]] ne "synth_design Complete!"} {
        error "Синтез не завершён успешно"
    }

    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property STATUS [get_runs impl_1]] ne "write_bitstream Complete!"} {
        error "Implementation или создание bitstream не завершены успешно"
    }
    # Настройки flash необязательны и хранятся рядом с проектом.
    set flash_config [file join [file dirname $project_file] flash.tcl]
    if {[file exists $flash_config]} {
        source $flash_config
        set impl_dir [get_property DIRECTORY [get_runs impl_1]]
        set top [get_property TOP [get_filesets sources_1]]
        set project_name [file rootname [file tail $project_file]]
        write_cfgmem -force -format mcs -size $flash_size -interface $flash_interface \
            -loadbit [list up $flash_address [file join $impl_dir ${top}.bit]] \
            -file [file join $impl_dir ${project_name}.mcs]
    }
    close_project
} message]} {
    puts stderr "ERROR: $message"
    exit 1
}
