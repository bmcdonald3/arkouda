
module SymArrayDmap
{
    use ChplConfig;

    /*
     Available domain maps.
     */
    enum Dmap {defaultRectangular, blockDist};

    private param defaultDmap = if CHPL_COMM == "none" then Dmap.defaultRectangular
                                                       else Dmap.blockDist;
    /*
    How domains/arrays are distributed. Defaults to :enum:`Dmap.defaultRectangular` if
    :param:`CHPL_COMM=none`, otherwise defaults to :enum:`Dmap.blockDist`.
    */
    config param MyDmap:Dmap = defaultDmap;

    public use BlockDist;

    /* 
    Makes a domain distributed according to :param:`MyDmap`.

    :arg size: size of domain
    :type size: int
    */
    proc makeDistDom(size:int, param ndims=1) {
      if ndims == 1 then
        return {0..#size};
      else
        return {0..#size, 0..#size};
    }
    
    /* 
    Makes an array of specified type over a distributed domain

    :arg size: size of the domain
    :type size: int 

    :arg etype: desired type of array
    :type etype: type

    :returns: [] ?etype
    */
    proc makeDistArray(size:int, type etype, param ndims=1) {
        var a: [makeDistDom(size, ndims)] etype;
        return a;
    }

    /* 
    Returns the type of the distributed domain

    :arg size: size of domain
    :type size: int

    :returns: type
    */
    proc makeDistDomType(size: int) type {
        return makeDistDom(size).type;
    }

}
