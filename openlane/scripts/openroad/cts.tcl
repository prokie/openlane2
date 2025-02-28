# Copyright 2020-2022 Efabless Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
source $::env(SCRIPTS_DIR)/openroad/common/io.tcl
source $::env(SCRIPTS_DIR)/openroad/common/resizer.tcl

load_rsz_corners
read_current_odb

# set rc values
source $::env(SCRIPTS_DIR)/openroad/common/set_rc.tcl
estimate_parasitics -placement

# Clone clock tree inverters next to register loads
# so cts does not try to buffer the inverted clocks.
repair_clock_inverters

puts "\[INFO\] Configuring cts characterization…"
set cts_characterization_args [list]
lappend cts_characterization_args -max_cap [expr {$::env(CTS_MAX_CAP) * 1e-12}]; # pF -> F
if { [info exists ::env(MAX_TRANSITION_CONSTRAINT)] } {
    lappend cts_characterization_args -max_slew [expr {$::env(MAX_TRANSITION_CONSTRAINT) * 1e-9}]; # ns -> S
}
configure_cts_characterization {*}$cts_characterization_args

puts "\[INFO] Performing clock tree synthesis…"
puts "\[INFO] Looking for the following net(s): $::env(CLOCK_NET)"
puts "\[INFO] Running Clock Tree Synthesis…"

set arg_list [list]

lappend arg_list -buf_list $::env(CTS_CLK_BUFFERS)
lappend arg_list -root_buf $::env(CTS_ROOT_BUFFER)
lappend arg_list -sink_clustering_size $::env(CTS_SINK_CLUSTERING_SIZE)
lappend arg_list -sink_clustering_max_diameter $::env(CTS_SINK_CLUSTERING_MAX_DIAMETER)
lappend arg_list -sink_clustering_enable

if { $::env(CTS_DISTANCE_BETWEEN_BUFFERS) != 0 } {
    lappend arg_list -distance_between_buffers $::env(CTS_DISTANCE_BETWEEN_BUFFERS)
}

if { $::env(CTS_DISABLE_POST_PROCESSING) } {
    lappend arg_list -post_cts_disable
}

clock_tree_synthesis {*}$arg_list

set_propagated_clock [all_clocks]

estimate_parasitics -placement
puts "\[INFO] Repairing long wires on clock nets…"
# CTS leaves a long wire from the pad to the clock tree root.
repair_clock_nets -max_wire_length $::env(CTS_CLK_MAX_WIRE_LENGTH)

estimate_parasitics -placement
write_views

puts "\[INFO\] Legalizing…"
source $::env(SCRIPTS_DIR)/openroad/common/dpl.tcl

estimate_parasitics -placement

write_views

puts "%OL_CREATE_REPORT cts.rpt"
report_cts
puts "%OL_END_REPORT"

report_design_area_metrics

