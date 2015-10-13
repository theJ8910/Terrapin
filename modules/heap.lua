--Note: in this file we talk about "comparison functions".
--This is a function that takes two values, compares them, and returns
--true or false based on the result of the comparison.
--If the comparison function returns true, this indicates to the heap that the first value should be placed closer to the top of the heap than the second value.
--Minheaps (ordered such that the smallest item winds up on top) uses a "less than" comparison function.
--e.g. a < b
--Maxheaps (ordered such that the largest item winds up on top) uses a "greater than" comparison function.
--e.g. a > b


local heapfn = {}

local heapmt = {}
heapmt.__index = heapfn


--basic less than comparison function; use for minheap
function lt( a, b ) return a < b end

--basic greater than comparison function; use for maxheap
function gt( a, b ) return a > b end



--Makes a new heap
function new( comparefn )
    local t = { ["comparefn"] = comparefn }
    setmetatable( t, heapmt )
    
    --Heaps have a hash table that record the position
    --of each element in the heap (by key) for fast searching
    --best case, heap contains no duplicate keys and searches are O(1)
    --worst case, all heap entries have the same key and searches are O(n)
    --but this is fine because searching the values stored in the heap
    --without the aid of the hashtable would take O(n) anyway
    t.ht = {}
    
    return t
end

--Makes a new minheap (standard < comparison)
function newminheap()
    return new( lt )
end

--Makes a new maxheap (standard > comparison)
function newmaxheap()
    return new( gt )
end

--Heap hashtable maintainence functions

--Records a new val @ index
local function heapht_insert( heap, val, index )
    if heap.ht[val] == nil then heap.ht[val] = {} end
    table.insert( heap.ht[val], index )
end

--Records that val @ index no longer exists
local function heapht_remove( heap, val, index )
    for k, v in ipairs( heap.ht[val] ) do
        if v == index then
            table.remove( heap.ht[val], k )
            if #heap.ht[val] < 1 then heap.ht[val] = nil end
            return
        end
    end
end

--Records that val @ index is now val @ newindex
local function heapht_move( heap, val, oldindex, newindex )
    for k, v in ipairs( heap.ht[val] ) do
        if v == oldindex then
            heap.ht[val][k] = newindex
            return
        end
    end
end



--Called after inserting a value in the heap.
--One of two functions that maintain heap ordering.
--Values larger (for a minheap) or smaller (for a maxheap) than "value"
--along a path from the empty spot at the bottom of the heap
--to the root at the top of the heap will sink down one hierarchical level
--to make room for the new value.
--This function operates in O( log_2(n) ).
--size should be the OLD size of the heap (if the heap had 2 items before the value was inserted, give 2)
--value should be the new value that was inserted
--The index the new value can be placed in is returned.
local function siftdown( heap, size, value )
    local index = size + 1
    local parent, parentindex
    while index > 1 do
        parentindex = math.floor( index / 2 )
        parent      = heap[parentindex]
        if heap.comparefn( value, parent ) then
            heapht_move( heap, parent, parentindex, index )
            heap[index] = parent
            index = parentindex
        else
            break
        end
    end
    
    return index
end

--Called after removing a value with key @ index from heap.
--One of two functions that maintain heap ordering.
--After a value is removed from the heap, a value needs to take it's place.
--We borrow the last element in the heap (a large element in a minheap, or a small element in a maxheap)
--and place it in the removed spot. Then, the smallest/largest value (in a minheap/maxheap respectively)
--directly beneath that spot will continually move upward, swapping places with the value,
--until a smaller/larger value is no longer available.
--This function operates in O( log_2(n) ).
--heap[index] is expected to be nil
--size should be the OLD size of the heap (if the heap had 5 items before the value was removed, give 5)
--index should be the index of the removed item
local function siftup( heap, size, index )
    --If the index that was removed was the last item, there's nothing for us to sift up.
    if index == size then return end
    
    --Since heaps are near-complete binary trees,
    --we need to move particular nodes to preserve this property.
    --Moving the last node in the tree, determined by viewing the tree
    --in a left-to-right, top-to-bottom order, is a safe way to preserve
    --this property.
    local last = heap[size]
    heap[size] = nil
    
    --As long as the current node has at least one child...
    local child, childindex, child2index
    while index * 2 < size do
        --...select the child that passes the comparison function and sift it upwards into the empty slot.
        --This needs to be done to preserve the heap order of the tree.
        --Each time this is done, the position the child previously occupied becomes an empty slot.
        --We need to continue moving nodes until finally the (previously last node) occupies the final empty slot.
        --e.g. if "1" is removed, and has "3" and "5" as children, "5" would be larger than "3"
        --and therefore would be an inappropriate choice, so "3" is chosen instead.
        childindex  = index * 2
        child2index = childindex + 1
        if child2index < size and heap.comparefn( heap[child2index], heap[childindex] ) then
            childindex = child2index
        end
        child = heap[childindex]
        
        --We can stop sifting nodes up when the selected child node
        --fails a comparison against the last item in the heap.
        --At that point, all items passing the comparison are above the empty slot,
        --and all items failing the comparison are below the empty slot, ensuring the ordering property
        --would be preserved if the last item was moved to the empty slot.
        if heap.comparefn( child, last ) then
            heapht_move( heap, child, childindex, index )
            
            heap[index] = child
            index       = childindex
        else
            break
        end
    end
    
    --Finally, shift the last node into it's new position
    heap[index] = last
    heapht_move( heap, last, size, index )
end

--Returns true if the heap is empty
function heapfn:isempty()
    return #self < 1
end

--Returns true if the heap isn't empty
function heapfn:notempty()
    return #self > 0
end

--Returns number of entries in the heap
function heapfn:size()
    return #self
end

--Returns the value at the top of the heap, nil if the heap is empty
function heapfn:top()
    return self[1]
end

--Inserts a value in the heap and sorts it to it's appropriate position
--the heap's comparison function determine where the value is placed in the heap
function heapfn:enqueue( val )
    local index = siftdown( self, #self, val )
    self[index] = val
    heapht_insert( self, val, index )
end

--Removes the value at the top of the heap and returns it
function heapfn:dequeue()
    local size = #self
    if size < 1 then return nil end
    
    local top = self[1]
    self[1] = nil
    heapht_remove( self, top, 1 )
    
    siftup( self, size, 1 )
    
    return top
end

--Searches for val and removes it from the heap
--Returns true if the value was found and removed, false otherwise
--If there are multiple copies of this value, only the first value found is removed
function heapfn:remove( val )
    local size = #self
    if size < 1 then return false end

    local index = self:search( val )
    if index == nil then return false end
    
    heapht_remove( self, val, index )
    self[index] = nil
    
    siftup( self, size, index )
    
    return true
end

--Deletes everything in the heap
function heapfn:empty()
    for k in ipairs( self ) do self[k] = nil end
    self.ht = {}
end

--Searches for first instance of val
--Returns the position val is at in the heap if the node could be found, nil otherwise
function heapfn:search( val )
    return self.ht[val] and self.ht[val][1]
end

--Returns true if at least one copy of val is stored in the heap
function heapfn:contains( val )
    return self:search( val ) ~= nil
end

--Returns how many copies of val are in the heap
function heapfn:count( val )
    return ( self.ht[val] and #self.ht[val] ) or 0
end



