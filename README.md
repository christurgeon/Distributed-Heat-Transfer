# Distributed Heat Transfer

An concurrent and distrubuted way of calculating information on airplanes using JoCaml.

## Authors
Daniel Tabin (tabind)
Chris Turgeon (turgec)

## Notes on the programs:
We created two programs.  Our initial program had a dynamic number of concurrent workers.  It splits the board into a given number of workers who each are in charge of a certain number of rows.  The total number of rows is evenly distributed among the workers.  Workers know their above and below neighbors, and can get the neighboring sections of the total board.  This allows them to calculate the edges of their portion of the surface.  Unfortuneately, it proved very difficult to get a dynamic number of workers to run in a distributed manor, so we have another program that demonstrates distributed jocaml; however it has a set number of four workers.

The distributed solution configures four workers on four servers, the client code builds the board it wants with the same partitions matching the workers then connects to each server. It has access to four compute methods to compute the next iteration for a given subsection of the board. It calls compute for each portion of the board and when the workers complete it joins the board and then distriubtes it out again for the next iteration. 

## Running the Program with a dynamic number of concurrent workers:
This program can be ran by typing `jocaml non_distributed.ml` and the size of board, number of iterations, and number of partitions can be determined at the top of the program.  The number of partitions must be greater than 1 and less than the height.

## Running the distributed program:
In order to run the servers, run ```./run.sh``` in a terminal (bash / unix) and then in a separate terminal run ```jocaml client.ml``` once the servers are running. You can type any key to quit out of the bash script and kill the client server processes. Result will appear through stdout on the client terminal. 

## Analysis of distrubed vs non distributed:
A distributed iterative computation will have higher performance when the speedup gained by the parallelism exceeds the cost of communication between agents. Additionally, factors like localized communication will beat communication over great distances.  Thus distribution of multiple threads on the same computer may beat out distribution over the internet; however distributing over greater distances allows for more total processing power to be added to the ssytem. Sometimes fewer communications over great distances can beat many communications over short differences, although longer communications and communication over networks can incur orders of magnitude of time versus, say, inter-process communication. Data partitioning also comes into play and can affect the other factors. If a data source is large, it helps distriubted computing to place it closer in proximity. Of course moving around larger chunks of data can slow down progress gained from distribution. Ideally, if we can break up return chunks into minimal sizes required we can observe speedups. For example, the agents in the dyanmic local solution here only return the subset that they compute versus the entire board. 
