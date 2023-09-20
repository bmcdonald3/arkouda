module ArkoudaBlockCompat {

  use BlockDist;

  type blockDist = Block;

  proc blockDist.distribution {
    return this.dist;
  }
}