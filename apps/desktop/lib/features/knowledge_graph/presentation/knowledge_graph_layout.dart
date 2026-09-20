/// Which GraphView layout algorithm renders the graph.
enum GraphLayoutMode {
  /// Sugiyama layered layout: subjects arranged top-to-bottom by
  /// prerequisite depth. Best default for a directed prerequisite graph
  /// because the reading order matches the actual "must come before" order.
  hierarchy,

  /// Fruchterman-Reingold force-directed layout: an organic network view,
  /// more legible once learning-outcome nodes are switched on and the graph
  /// stops being a clean DAG-shaped hierarchy.
  network,
}
