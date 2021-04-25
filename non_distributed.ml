(*
    Configuration constants
*)
let width  = 100 ;; 
let height = 100 ;;
let partitions = 25 ;; (* assume > 1  and < height*)
let iterations = 100 ;;

(* return the first row of a sub-surfac *)
let get_surf_top surf =
    Array.get surf 0;;

(* return the last row of a sub-surfac *)
let get_surf_bot surf =
    Array.get surf ((Array.length surf) -1);;

(* given an x and y coordinate, it returns a list of x,y tuples that are the neighbors *)
let neighbor_vals w h = 
    [
        (w,   h+1);
        (w+1, h+1);
        (w+1, h);
        (w+1, h-1);
        (w,   h-1);
        (w-1, h-1);
        (w-1, h);
        (w-1, h+1);
    ] ;;

(*  given a position return either the value in the surface, the value
    in the neighbor, 0 if the value is invalid.  Also return in the tuple
    if the value is valid or not*)
let valid_bounds coords board above below max_w max_h = 
    let w, h = coords in
        if ((w >= 0) && (w < max_w) && (h >= 0) && (h < max_h)) then
            (board.(w).(h), 1.0)
        else if ((h < 0) || (h >= max_w)) then
            (0.0, 0.0)
        else if ((w == -1) && (above != [||])) then
            (above.(h), 1.0)
        else if ((w == max_w) && (below != [||])) then
            (below.(h), 1.0)
        else 
            (0.0, 0.0);;
(* 
    Get all of the neighbors and sum them before dividing by the number of
    valid neighbors
*)
let rec compute_average board above below max_w max_h neighbors_list curr_sum num_valid_neighbors = match neighbors_list with
    | [] -> curr_sum /. num_valid_neighbors
    | head::body ->
        let (curr_val, is_valid) = (valid_bounds head board above below max_w max_h) in
            (compute_average board above below max_w max_h body (curr_sum +. curr_val) (num_valid_neighbors +. is_valid))

(* 
    Go through each w,h index of the board and update its value by averaging over its neighbors
 *)
let update_board_f board above below =
    let max_h = (Array.length (Array.get board 0)) in
    let max_w = (Array.length board) in
        Array.init max_w (fun w -> 
            Array.init max_h (fun h ->
                (compute_average board above below max_w max_h (neighbor_vals w h) 0.0 0.0)
        )) ;;

(* 
    Get the bottom row of the "above" worker's sub-surface
*)
let update_above_f top = 
    top();;

(* 
    Get the top row of the "below" worker's sub-surface
*)
let update_below_f bot =
    bot();;

(* 
    empty function which can be used if you don't have a neighboring worker on one or both sides
*)
let empty_n() = [||];;

(*
    Init a worker with a starting sub surface.
    Workers can:
        return their surface
        be given a new surface
        return the top row of their surface
        return the bottom row of their surface
        be given a pair of neighbors (above and below)
        obtain the bottom row of the above neighbor
        obtain the top row of the below neighbor
        update their surface
    Workers store:
        their surface
        the functions which give them their neighbors' data
        the row above and below them
*)
let worker starting_surf =
    def board(surf) & get_board() = board(surf) & reply surf to get_board
    or board(_) & set_board(surf) = board(surf) & reply to set_board
    or board(surf) & get_top() = board(surf) & reply (get_surf_top surf) to get_top
    or board(surf) & get_bot() = board(surf) & reply (get_surf_bot surf) to get_bot
    or neighbors(_1, _2) & set_neighbors(top, bot) = neighbors(top, bot) & reply to set_neighbors
    or ghost_rows(_, below) & neighbors(top, bot) & update_above() = ghost_rows((update_above_f top), below) & neighbors(top, bot) & reply to update_above
    or ghost_rows(above, _) & neighbors(top, bot) & update_below() = ghost_rows(above, (update_below_f bot)) & neighbors(top, bot) & reply to update_below
    or board(surf) & ghost_rows(above, below) & update_board() = board(update_board_f surf above below) & ghost_rows(above, below) & reply to update_board in
        spawn board(starting_surf) & ghost_rows([||], [||]) & neighbors(empty_n, empty_n) ;
        (get_board, set_board, get_top, get_bot, set_neighbors, update_above, update_below, update_board) ;;

(* append two lists *)
let append xs ys = List.rev_append (List.rev xs) ys

(* 
    Build the 2D surface array
*)
let surface = 
    Array.init height (fun h -> 
        Array.init width (fun w ->
            if (w == 0) || (h > 30 && h < 91) then 100.0 else 20.0)) ;; 

(* Build array of partition start locations *)
let part_starts = Array.init partitions (fun w -> ((w*width)/partitions)) ;;

(* Build array of partition lengths *)
let part_lngths = Array.init partitions (fun w ->
    if (w < (partitions -1)) then
        (part_starts.(w+1) - part_starts.(w))
    else
        (width - part_starts.(w))
)
(*
    Showing how to print a 2D float array
*)
let farr_to_string arr = print_endline (Array.fold_left (fun acc elem -> acc ^ "\t" ^ (string_of_float elem)) "" arr) ;; 

(*
    Showing how to print a 1D int array
*)
let iarr_to_string arr = print_endline (Array.fold_left (fun acc elem -> acc ^ "\t" ^ (string_of_int elem)) "" arr) ;; 

(* print the bounds of the partitions *)
let () = (iarr_to_string part_starts) ;;
let () = (iarr_to_string part_lngths) ;;

(* 
    divide up the surface into subsurrfaces for workers
*)
let inital_subarrays = Array.init partitions (fun p ->
    (Array.sub surface part_starts.(p) part_lngths.(p))) ;;

(* 
    function that combines sub-surfaces back into a single surface
*)
let cmbine_subarrays sub_arrays =
    let output = (Array.init height ( fun w -> Array.init width (fun h -> 0.0))) in
        for i = 0 to (partitions - 1) do
            Array.blit sub_arrays.(i) 0 output part_starts.(i) part_lngths.(i)
        done ;
        output ;;

(* 
    recursively make a list of workers
    this is a list of tuples, and each tuple is a tuple of functions from the worker
*)
let rec make_workers i =
    if i < partitions then
        ([(worker inital_subarrays.(i))] @ (make_workers (i+1)))
    else
        []
    ;;

(*
    The next set of functions extract a single function from each tuple in the list
    of worker tuples.  These are then put into their own lists, so they can be accessed
    directly without having to search through the worker tuples.  The indexes remain
    the same as the original worker list.
    Note: these take in an array, not a list so the worker list must be converted
*)
let rec w_get_boards workers i = 
    if i < partitions then
    let (wgb, _1, _2, _3, _4, _5, _6, _7) = workers.(i) in
        ([wgb] @ (w_get_boards workers (i+1)))
    else
        []
    ;;
let rec w_set_boards workers i = 
    if i < partitions then
    let (_1, wsb, _2, _3, _4, _5, _6, _7) = workers.(i) in
        ([wsb] @ (w_set_boards workers (i+1)))
    else
        []
    ;;
let rec w_get_tops workers i = 
    if i < partitions then
    let (_1, _2, wgt, _3, _4, _5, _6, _7) = workers.(i) in
        ([wgt] @ (w_get_tops workers (i+1)))
    else
        []
    ;;
let rec w_get_bots workers i = 
    if i < partitions then
    let (_1, _2, _3, wgb, _4, _5, _6, _7) = workers.(i) in
        ([wgb] @ (w_get_bots workers (i+1)))
    else
        []
    ;;
let rec w_set_neighbors workers i = 
    if i < partitions then
    let (_1, _2, _3, _4, wsn, _5, _6, _7) = workers.(i) in
        ([wsn] @ (w_set_neighbors workers (i+1)))
    else
        []
    ;;
let rec w_update_aboves workers i = 
    if i < partitions then
    let (_1, _2, _3, _4, _5, wua, _6, _7) = workers.(i) in
        ([wua] @ (w_update_aboves workers (i+1)))
    else
        []
    ;;
let rec w_update_belows workers i = 
    if i < partitions then
    let (_1, _2, _3, _4, _5, _6, wub, _7) = workers.(i) in
        ([wub] @ (w_update_belows workers (i+1)))
    else
        []
    ;;
let rec w_update_boards workers i = 
    if i < partitions then
    let (_1, _2, _3, _4, _5, _6, _7, wub) = workers.(i) in
        ([wub] @ (w_update_boards workers (i+1)))
    else
        []
    ;;

(* 
    Make array of workers and of each function
*)
let worker_arr = (Array.of_list (make_workers 0)) ;;
let get_board_arr = (Array.of_list (w_get_boards worker_arr 0)) ;;
let set_board_arr = (Array.of_list (w_set_boards worker_arr 0)) ;;
let get_tops_arr = (Array.of_list (w_get_tops worker_arr 0)) ;;
let get_bots_arr = (Array.of_list (w_get_bots worker_arr 0)) ;;
let set_neighbor_arr = (Array.of_list (w_set_neighbors worker_arr 0)) ;;
let update_above_arr = (Array.of_list (w_update_aboves worker_arr 0)) ;;
let update_below_arr = (Array.of_list (w_update_belows worker_arr 0)) ;;
let update_board_arr = (Array.of_list (w_update_boards worker_arr 0)) ;;

(*
    Send each surface the funcitons of their neighbors
*)
for i = 0 to partitions -1 do
    print_int i;
    if (i == 0) then
        set_neighbor_arr.(i)(empty_n, get_tops_arr.(i + 1))
    else if (i == (partitions - 1)) then
        set_neighbor_arr.(i)(get_bots_arr.(i - 1), empty_n)
    else
        set_neighbor_arr.(i)(get_bots_arr.(i - 1), get_tops_arr.(i + 1))
    ;
done ;;

(*
    Function that gets the sub-surfaces from each worker
*)
let rec extract_sub_boards sub_boards_func_arr i =
    if i < partitions then
        ([sub_boards_func_arr.(i)()] @ (extract_sub_boards sub_boards_func_arr (i+1)))
    else
        []
    ;;
(*
    Function for printing a combined surface at any generation
*)
let print_board sub_boards i =
    let cur_board = (cmbine_subarrays sub_boards) in
        print_string "Board at iteration ";
        print_int (i);
        print_endline ":";
        (Array.iter farr_to_string cur_board);;

(*
    Iterate for each iteration.  Update the above and below rows before
    updating the boards to avoid raceconditions and deadlock
*)
for i = 0 to iterations do
    print_board (Array.of_list (extract_sub_boards get_board_arr 0)) i ;
    for j = 0 to partitions - 1 do
        update_above_arr.(j)()
    done;
    for j = 0 to partitions - 1 do
        update_below_arr.(j)()
    done;
    for j = 0 to partitions - 1 do
        update_board_arr.(j)()
    done;
done ;;