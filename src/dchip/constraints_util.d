/*
 * Copyright (c) 2007-2013 Scott Lembcke and Howling Moon Software
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
module dchip.constraints_util;

import dchip.chipmunk;
import dchip.chipmunk_types;
import dchip.cpBody;
import dchip.cpConstraint;
import dchip.cpVect;

// These are utility routines to use when creating custom constraints.
// I'm not sure if this should be part of the private API or not.
// I should probably clean up the naming conventions if it is...

cpVect relative_velocity(cpBody* a, cpBody* b, cpVect r1, cpVect r2)
{
    cpVect v1_sum = cpvadd(a.v, cpvmult(cpvperp(r1), a.w));
    cpVect v2_sum = cpvadd(b.v, cpvmult(cpvperp(r2), b.w));

    return cpvsub(v2_sum, v1_sum);
}

cpFloat normal_relative_velocity(cpBody* a, cpBody* b, cpVect r1, cpVect r2, cpVect n)
{
    return cpvdot(relative_velocity(a, b, r1, r2), n);
}

void apply_impulse(cpBody* body_, cpVect j, cpVect r)
{
    body_.v  = cpvadd(body_.v, cpvmult(j, body_.m_inv));
    body_.w += body_.i_inv * cpvcross(r, j);
}

void apply_impulses(cpBody* a, cpBody* b, cpVect r1, cpVect r2, cpVect j)
{
    apply_impulse(a, cpvneg(j), r1);
    apply_impulse(b, j, r2);
}

void apply_bias_impulse(cpBody* body_, cpVect j, cpVect r)
{
    body_.v_bias  = cpvadd(body_.v_bias, cpvmult(j, body_.m_inv));
    body_.w_bias += body_.i_inv * cpvcross(r, j);
}

void apply_bias_impulses(cpBody* a, cpBody* b, cpVect r1, cpVect r2, cpVect j)
{
    apply_bias_impulse(a, cpvneg(j), r1);
    apply_bias_impulse(b, j, r2);
}

cpFloat k_scalar_body(cpBody* body_, cpVect r, cpVect n)
{
    cpFloat rcn = cpvcross(r, n);
    return body_.m_inv + body_.i_inv * rcn * rcn;
}

cpFloat k_scalar(cpBody* a, cpBody* b, cpVect r1, cpVect r2, cpVect n)
{
    cpFloat value = k_scalar_body(a, r1, n) + k_scalar_body(b, r2, n);
    cpAssertSoft(value != 0.0, "Unsolvable collision or constraint.");

    return value;
}

cpMat2x2 k_tensor(cpBody* a, cpBody* b, cpVect r1, cpVect r2)
{
    cpFloat m_sum = a.m_inv + b.m_inv;

    // start with Identity*m_sum
    cpFloat k11 = m_sum, k12 = 0.0f;
    cpFloat k21 = 0.0f, k22 = m_sum;

    // add the influence from r1
    cpFloat a_i_inv = a.i_inv;
    cpFloat r1xsq   =  r1.x * r1.x * a_i_inv;
    cpFloat r1ysq   =  r1.y * r1.y * a_i_inv;
    cpFloat r1nxy   = -r1.x * r1.y * a_i_inv;
    k11 += r1ysq;
    k12 += r1nxy;
    k21 += r1nxy;
    k22 += r1xsq;

    // add the influnce from r2
    cpFloat b_i_inv = b.i_inv;
    cpFloat r2xsq   =  r2.x * r2.x * b_i_inv;
    cpFloat r2ysq   =  r2.y * r2.y * b_i_inv;
    cpFloat r2nxy   = -r2.x * r2.y * b_i_inv;
    k11 += r2ysq;
    k12 += r2nxy;
    k21 += r2nxy;
    k22 += r2xsq;

    // invert
    cpFloat det = k11 * k22 - k12 * k21;
    cpAssertSoft(det != 0.0, "Unsolvable constraint.");

    cpFloat det_inv = 1.0f / det;
    return cpMat2x2New(
        k22 * det_inv, -k12 * det_inv,
        -k21 * det_inv, k11 * det_inv
        );
}

cpFloat bias_coef(cpFloat errorBias, cpFloat dt)
{
    return 1.0f - cpfpow(errorBias, dt);
}
