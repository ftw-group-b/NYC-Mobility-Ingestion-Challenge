# Gold Mart Validation

The Gold validation notebook verifies:

- complete Date coverage for pickup and drop-off roles;
- governed Time keys, including the Unknown member;
- unique Taxi Zone and Weather keys;
- one Gold fact row per accepted Silver trip row;
- reconciliation of distance, duration, and retained financial measures;
- complete fact keys and foreign-key resolution;
- unchanged row cardinality after dimension joins; and
- stable business results across reruns.

The consolidated quality gate repeats the merge-blocking row, measure, key, relationship, and lineage controls.
