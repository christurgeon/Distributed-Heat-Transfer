let number = int_of_string Sys.argv.(1)
let wl = int_of_string Sys.argv.(2)
let wh = int_of_string Sys.argv.(3)
let hl = int_of_string Sys.argv.(4)
let hh = int_of_string Sys.argv.(5)
let port = int_of_string Sys.argv.(6)
let () = Printf.printf "%d: %d %d %d %d port: %d\n" number wl wh hl hh port

let addr = Unix.ADDR_INET (Join.Site.get_local_addr(), port)
let () = Join.Site.listen addr

let width  = 122 ;; 
let height = 122 ;;
let debug = false ;;

(* Returns True if point is within the grid boundaries *)
let valid_bounds coords = 
    let x, y = coords in 
        (x >= 0) && (x < width) && (y >= 0) && (y < height) ;; 

(* given an x and y coordinate, it returns a list of x,y tuples that are the neighbors *)
let neighbors w h = [
  (w,   h+1);
  (w+1, h+1);
  (w+1, h);
  (w+1, h-1);
  (w,   h-1);
  (w-1, h-1);
  (w-1, h);
  (w-1, h+1);
] ;;

(*
    Computes the next iteration values and returns a partition 2D surface,
    note that it is only returning a 2D array with dimensions the size of the partition.
        - curr_surface : full 2D surface for current iteration
        - width_lower  : starting width value for this partition inside curr_surface (inclusive)
        - width_upper  : ending width value for this partition (NON-inclusive)
        - height_lower : starting height value for this partition inside curr_surface (inclusive)
        - height_upper : ending width value for this partition (NON-inclusive)
*)
let compute_partition curr_surface width_lower width_upper height_lower height_upper = 
    let rec compute_average curr_surface neighbors_list curr_sum num_valid_neighbors = match neighbors_list with
        | [] -> curr_sum /. num_valid_neighbors
        | head::body ->
            let (w, h) = head in 
            if (valid_bounds head) then 
                (compute_average curr_surface body (curr_sum +. curr_surface.(h).(w)) (num_valid_neighbors +. 1.0)) 
            else 
                (compute_average curr_surface body curr_sum num_valid_neighbors) and
        height = height_upper-height_lower and 
        width  = width_upper-width_lower in 
        Array.init height (fun h -> 
            Array.init width (fun w -> 
                if debug then print_endline ("w,h : " ^ (string_of_int (width_lower + w)) ^ "," ^ (string_of_int (height_lower + h))) ; 
                (compute_average curr_surface (neighbors (width_lower + w) (height_lower + h)) 0.0 0.0)
        )) ;;

(*
    Function to be accessible to client code, takes in a surface and computes the subgrid
*)
def compute(s) = 
        reply (compute_partition s wl wh hl hh) to compute in
            Join.Ns.register Join.Ns.here ("compute" ^ (string_of_int number)) compute ;;
  
let wait = 
    def x() & y() = 
        reply to x in x ;; 

print_endline ("client " ^ (string_of_int number) ^ " running...") 

let main = wait() ;;