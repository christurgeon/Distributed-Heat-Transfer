let addr =
    if Array.length Sys.argv > 1 then
        (Unix.gethostbyname Sys.argv.(1)).Unix.h_addr_list.(0)
    else
        Join.Site.get_local_addr ()

let server1 = Join.Site.there (Unix.ADDR_INET(addr, 12345)) ;;
let server2 = Join.Site.there (Unix.ADDR_INET(addr, 12346)) ;;
let server3 = Join.Site.there (Unix.ADDR_INET(addr, 12347)) ;;
let server4 = Join.Site.there (Unix.ADDR_INET(addr, 12348)) ;;

let () =  Join.Site.at_fail server1 (def bye() = exit 0 ; 0 in bye)
let () =  Join.Site.at_fail server2 (def bye() = exit 0 ; 0 in bye)
let () =  Join.Site.at_fail server3 (def bye() = exit 0 ; 0 in bye)
let () =  Join.Site.at_fail server4 (def bye() = exit 0 ; 0 in bye)

let ns1 = Join.Ns.of_site server1
let ns2 = Join.Ns.of_site server2
let ns3 = Join.Ns.of_site server3
let ns4 = Join.Ns.of_site server4

(* looks up the compute methods that each server has *)
let compute1 = Join.Ns.lookup ns1 "compute1"
let compute2 = Join.Ns.lookup ns2 "compute2"
let compute3 = Join.Ns.lookup ns3 "compute3"
let compute4 = Join.Ns.lookup ns4 "compute4"


(*************************************************************************)
(*************************************************************************)


(*
    Configuration constants
*)
let width  = 122 ;; 
let height = 122 ;;
let partitions = 4 ;; (* assume even value *)
let partition_rows = partitions/2 ;;
let debug = false ;; 

(* 
    Build the 2D surface array
*)
let surface = 
    Array.init height (fun h -> 
        Array.init width (fun w ->
            if (w == 0) || (h > 30 && h < 91) then 100.0 else 20.0)) ;; 

(*
    Showing how to print a 2D float array
*)
let farr_to_string arr = print_endline (Array.fold_left (fun acc elem -> acc ^ " " ^ (string_of_float elem)) "" arr) ;; 

(* Takes a surface, a partition of the surface and the indeces denoting the location 
   of the subsurface in the surface. It returns a fully sized board with the partition added *)
let merge_partition surface partition_s wl wh hl hh =
    if debug then 
    begin 
        Printf.printf "running ... %d,%d,%d,%d for %dx%d\n" wl wh hl hh width height ; 
        (Array.iter farr_to_string partition_s) 
    end ;
    Array.init height (fun h -> 
        Array.init width (fun w -> 
            if (w >= wl) && (w < wh) && (h >= hl) && (h < hh) then 
                begin 
                    if debug then (Printf.printf "%d,%d " (h-hl) (w-wl)) ;
                    partition_s.(h-hl).(w-wl)
                end else 
                    surface.(h).(w) 
    )) ;;

(* Takes in the full surface and a list of the agent workers as well as a list
   of the subsurface grids that the agents computed, it loops through both and 
   calls merge_partition to build the new fully sized grid from the subsurface grids *)
let rec merge_helper surface agents subsurfaces =    
    match agents with 
    | [] -> surface 
    | (_, bounds)::agents_tail -> 
            let (wl, wh, hl, hh) = bounds in 
                let new_surface = (merge_partition surface (List.hd subsurfaces) wl wh hl hh) in   
                    merge_helper new_surface agents_tail (List.tl subsurfaces) ;;

(* Client driver code, takes in initial surface and provides methods to progress to the 
   next board and to print at any time to see the current board, it uses four compute methods
   from four different servers *)
let progress_one_iteration surface =
    def grid(s) & agents(_) & init() =
        let a = [
            (compute1, (0,  61,  0,  61)) ; 
            (compute2, (0,  61,  61, 122)) ; 
            (compute3, (61, 122, 0,  61)) ; 
            (compute4, (61, 122, 61, 122)) ; 
        ] in
        grid(s) & agents(a) & reply to init
    or  grid(s) & agents(a) & next() = 
        let rec collector agent_list res = match agent_list with 
            | [] -> res 
            | (compute, _)::tail -> collector tail ([compute(s)] @ res) in 
            let new_surface = 
                (merge_helper s (List.rev a) (*maybe no reverse*) (collector a [])) in 
        grid(new_surface) & agents(a) & reply to next
    or  grid(s) & print() = 
        grid(s) & (print_endline "Current Board:" ; (Array.iter farr_to_string s) ; reply to print)
    in 
    spawn grid(surface) & agents([]) ;
    (init, next, print) ;; 

let init, next, print = progress_one_iteration surface ;;
init();
for i = 0 to 1024 do next() done; 
print();