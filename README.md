# Distributed Heat Transfer

A concurrent and distributed way of calculating the distribution of heat on a surface using JoCaml.

## Authors
Chris Turgeon and Daniel Tabin

## Notes on the programs:
We created two programs.  Our initial program had a dynamic number of concurrent workers.  It splits the board into a given number of workers who each are in charge of a certain number of rows.  The total number of rows is evenly distributed among the workers.  Workers know their above and below neighbors, and can get the neighboring sections of the total board.  This allows them to calculate the edges of their portion of the surface.  Unfortuneately, it proved very difficult to get a dynamic number of workers to run in a distributed manner, so we have another program that demonstrates distributed jocaml; however it has a set number of four workers. 

The distributed solution configures four workers on four servers, the client code builds the board it wants with the same partitions matching the workers then connects to each server. It has access to four compute methods to compute the next iteration for a given subsection of the board. It calls compute for each portion of the board and when the workers complete it joins the board and then distriubtes it out again for the next iteration. 

## Running Concurent Solution:
This program can be ran by typing `jocaml non_distributed.ml` and the size of board, number of iterations, and number of partitions can be determined at the top of the program.  The number of partitions must be greater than 1 and less than the height.

## Running Distributed Solution:
In order to run the servers, run ```./run.sh``` in a terminal (bash / unix) and then in a separate terminal run ```jocaml client.ml``` once the servers are running. You can type any key to quit out of the bash script and kill the client server processes. Result will appear through standard out on the client terminal. 
