set version 2016.2
puts "starting"

# Change to 1 to run SW emulation with gdb
set debug 0

# Define the solution for SDAccel
create_solution -name SORTING_multiple_128 -dir . -force
puts "created"

if {$version == "2016.2"} {
    add_device -vbnv xilinx:tul-pcie3-ku115:2ddr:3.0
} else {
    add_device -vbnv xilinx:adm-pcie-7v3:1ddr:2.1
}

# Host Compiler Flags
if {$debug} {
    set_property -name host_cflags -value "-g -Wall"  -objects [current_solution]
} else {
    set_property -name host_cflags -value "-Wall"  -objects [current_solution]
}

# Host Source Files
add_files "hostcode.cpp"

puts "creating kernel"
# Kernel Definition
create_kernel  bitonicSortLocal1 -type clc
create_kernel  bitonicMergeGlobal -type clc
create_kernel  bitonicMergeLocal -type clc

# Memory port optimization does NOT work when multiple compute units are
# instantiated.
#set_property max_memory_ports true [get_kernels bitonicSortLocal1]

# Workaround for the bug in kernel_flags, which does not pass the value to 
# the -D compiler option, only defines the macro as empty.
#exec cpp BitonicSort.cl > BitonicSort.tmp.cl
add_files -kernel [get_kernels bitonicSortLocal1] "BitonicSort.cl"
add_files -kernel [get_kernels bitonicMergeGlobal] "BitonicSort.cl"
add_files -kernel [get_kernels bitonicMergeLocal] "BitonicSort.cl"
if {$debug} {
    set_property -name kernel_flags -value "-g" -objects [get_kernels bitonicSortLocal1]
    set_property -name kernel_flags -value "-g" -objects [get_kernels bitonicMergeGlobal]
    set_property -name kernel_flags -value "-g" -objects [get_kernels bitonicMergeLocal]
}

puts "creating container"
# Define Binary Containers
create_opencl_binary bitonicsort
set_property region "OCL_REGION_0" [get_opencl_binary bitonicsort]

# The code below allocates the compute units optimally to maximize throughput
# under the constraint on the maximum numbr of memory ports.
# Creating 2 compute units for bitonicSortLocal1
create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicSortLocal1] -name bitonicSortLocal1_0

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicSortLocal1] -name bitonicSortLocal1_1

# Creating 4 compute units for bitonicMergeGlobal
create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeGlobal] -name bitonicMergeGlobal_0

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeGlobal] -name bitonicMergeGlobal_1

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeGlobal] -name bitonicMergeGlobal_2

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeGlobal] -name bitonicMergeGlobal_3

## Creating 4 compute units for bitonicMergeLocal
create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeLocal] -name bitonicMergeLocal_0

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeLocal] -name bitonicMergeLocal_1

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeLocal] -name bitonicMergeLocal_2

create_compute_unit -opencl_binary [get_opencl_binary bitonicsort] -kernel [get_kernels bitonicMergeLocal] -name bitonicMergeLocal_3

# Compile the design for CPU based emulation
puts "compiling for SW emulation"
compile_emulation -flow cpu -opencl_binary [get_opencl_binary bitonicsort]

# Run the compiled application in CPU based emulation mode
puts "running SW emulation"
if {$debug} {
    run_emulation -debug -flow cpu -args "bitonicsort.xclbin"
} else {
    run_emulation -flow cpu -args "bitonicsort.xclbin"
}

# Compile the design for hardware based emulation
puts "compiling for HW emulation"
compile_emulation -flow hardware -opencl_binary [get_opencl_binary bitonicsort]

# Run the compiled application in hardware based emulation mode
puts "running HW emulation"
run_emulation -flow hardware -args "bitonicsort.xclbin"

# report estimates
report_estimate

# Compile the application to run on the accelerator card
#build_system

# Package the application binaries
#package_system

