//===> Description ===>
//
// Initializes grid_base_defs and creates a method for a CTU
// (corner transport upwind) solver.
//
//<=== Description <===


use grid_base_defs;


//===> CTU update of a GridFunction ===>
//=====================================>
def RectangularGrid.advance_advection_ctu(q:              GridFunction,
					  velocity:       dimension*real,
                                          time_requested: real
                                          ) {

  //==== Make sure q can validly be updated ====
  assert(q.grid == this  &&  q.time <= time_requested);


  //===> Initialize ===>
  var cfl: [dimensions] real,
      dt_target:        real,
      dt_used:          real;

  var new_value: [all_cells] real;

  [d in dimensions] cfl(d) = dx(d) / abs(velocity(d));
  (dt_target,) = minloc reduce(cfl, dimensions);
  dt_target *= 0.95;
  //<=== Initialize <===
  

  
  //===> Time-stepping loop ===>
  while (q.time < time_requested) do {
    //==== Adjust the time step to hit time_requested if necessary ====
    if (q.time + dt_target > time_requested) then
      dt_used = time_requested - q.time;
    else
      dt_used = dt_target;
    writeln("Taking step of size dt=", dt_used, " to time ", q.time+dt_used, ".");


    //==== Fill in ghost cells ====
    q.boundary_manager.fill_ghost_cells(q);

    
    //-----------------------------------------------------------
    //---- Domain of alignments is [0..1, 0..1, ..., 0..1].
    //---- In each dimension, alignment 1 indicates that it's
    //---- aligned with the cel, and alignment 0 indicates that
    //---- it's upwind.  (What is "it"?)
    //-----------------------------------------------------------
    var alignments: domain(dimension);
    alignments = alignments.expand(1);
  
    //===> Update solution on each cell ===>
    forall cell_pretuple in physical_cells {

      //===> If dimension==1, the cell index must be tuple-ized ===>
      var cell: dimension*int;
      if cell_pretuple.type == int then
        cell(1) = cell_pretuple;
      else
        cell = cell_pretuple;
      //<=== If dimension==1, the cell index must be tuple-ized <===

      new_value(cell) = 0.0;
      var volume_fraction: real;
      var upwind_cell: dimension*int;
      for alignment_pretuple in alignments {
        //===> If dimension==1, the alignment must be tuple-ized ===>
        var alignment: dimension*int;
        if alignment_pretuple.type == int then
          alignment = tuple(alignment_pretuple);
        else
          alignment = alignment_pretuple;
        //<=== If dimension==1, the alignment must be tuple-ized <===
        
        volume_fraction = 1.0;
        for d in dimensions {
          //---- For each alignment, set the volume fraction and index
          //---- of the upwind cell. ---------------------------------
          if alignment(d) == 0 then {
            volume_fraction *= abs(velocity(d))*dt_used / dx(d);
            if velocity(d) < 0.0 then
              upwind_cell(d) = cell(d)+2;
            else // the case velocity(d)==0 can refer to any cell
              upwind_cell(d) = cell(d)-2;
          }
          else {
            volume_fraction *= 1.0 - abs(velocity(d))*dt_used / dx(d);
            upwind_cell(d) = cell(d);
          }
          
        }

          
        //==== Update cell value ====
        new_value(cell) += volume_fraction * q.value(upwind_cell);
  
      }
    
    }
    //<=== Update solution on each cell <===
    
  
  
    //==== Update solution ====
    q.value = new_value;
    q.time += dt_used;
          
  }
  //<=== Time-stepping loop <===


}
//<=== CTU update of a GridFunction <===
//<=====================================

