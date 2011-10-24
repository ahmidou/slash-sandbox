/*
 * Copyright (c) 2010-2011, NVIDIA Corporation
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *   * Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   * Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *   * Neither the name of NVIDIA Corporation nor the
 *     names of its contributors may be used to endorse or promote products
 *     derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <nih/octree/cuda/octree_builder.h>
#include <nih/sampling/random.h>
#include <nih/time/timer.h>

namespace nih {

void octree_test()
{
    fprintf(stderr, "octree test... started\n");

    const uint32 n_points = 4*1024*1024;
    const uint32 n_tests = 100;

    thrust::host_vector<Vector4f> h_points( n_points );

    Random random;
    for (uint32 i = 0; i < n_points; ++i)
        h_points[i] = Vector4f( random.next(), random.next(), random.next(), 1.0f );
    thrust::device_vector<Vector4f> d_points( h_points );
    thrust::device_vector<Vector4f> d_unsorted_points( h_points );

    thrust::device_vector<Octree_node_base> octree_nodes;
    thrust::device_vector<uint2>            octree_leaves;
    thrust::device_vector<uint32>           octree_index;

    Octree_builder builder( octree_nodes, octree_leaves, octree_index );

    cudaEvent_t start, stop;
    cudaEventCreate( &start );
    cudaEventCreate( &stop );

    float time = 0.0f;

    for (uint32 i = 0; i <= n_tests; ++i)
    {
        d_points = d_unsorted_points;
        cudaThreadSynchronize();

        float dtime;
        cudaEventRecord( start, 0 );

        builder.build(
            Bbox3f( Vector3f(0.0f), Vector3f(1.0f) ),
            d_points,
            16u );

        cudaEventRecord( stop, 0 );
        cudaEventSynchronize( stop );
        cudaEventElapsedTime( &dtime, start, stop );

        if (i) // skip the first run
            time += dtime;
    }
    time /= 1000.0f * float(n_tests);

    cudaEventDestroy( start );
    cudaEventDestroy( stop );

    fprintf(stderr, "octree test... done\n");
    fprintf(stderr, "  time       : %f ms\n", time * 1000.0f );
    fprintf(stderr, "  points/sec : %f M\n", (n_points / time) / 1.0e6f );

    fprintf(stderr, "  nodes  : %u\n", builder.m_node_count );
    fprintf(stderr, "  leaves : %u\n", builder.m_leaf_count );
    for (uint32 level = 0; level < 16; ++level)
        fprintf(stderr, "  level %u : %u nodes\n", level, builder.m_levels[level+1] - builder.m_levels[level] );

    thrust::host_vector<uint2> h_leaves( octree_leaves );
    uint32 n = 0;
    for (uint32 i = 0; i < builder.m_leaf_count; ++i)
        n += h_leaves[i].y - h_leaves[i].x;

    fprintf(stderr, "n : %u\n", n);
}

} // namespace nih

