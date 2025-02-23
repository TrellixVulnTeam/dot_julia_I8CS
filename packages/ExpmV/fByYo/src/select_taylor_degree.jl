using SparseArrays
using LinearAlgebra

const theta_double = [ 2.22045e-16, 2.58096e-8, 1.38635e-5, 0.000339717, 0.00240088,
0.00906566, 0.0238446, 0.0499123, 0.0895776, 0.144183, 0.214236,
0.299616, 0.399778, 0.513915, 0.641084, 0.780287, 0.930533, 1.09086,
1.26038, 1.43825, 1.62372, 1.81608, 2.01471, 2.21905, 2.42858, 2.64285,
2.86145, 3.084, 3.31017, 3.53967, 3.77221, 4.00756, 4.2455, 4.48582,
4.72835, 4.97292, 5.21938, 5.46759, 5.71744, 5.9688, 6.22158, 6.47568,
6.73102, 6.9875, 7.24507, 7.50365, 7.76317, 8.02359, 8.28485, 8.5469,
8.80969, 9.07319, 9.33734, 9.60212, 9.8675, 10.1334, 10.3999, 10.6669,
10.9343, 11.2022, 11.4705, 11.7392, 12.0084, 12.2778, 12.5477, 12.8178,
13.0883, 13.3591, 13.6302, 13.9016, 14.1732, 14.4451, 14.7172, 14.9896,
15.2622, 15.535, 15.808, 16.0812, 16.3546, 16.6281, 16.9019, 17.1758,
17.4498, 17.724, 17.9984, 18.2729, 18.5476, 18.8223, 19.0972, 19.3723,
19.6474, 19.9227, 20.198, 20.4735, 20.7491, 21.0248, 21.3005, 21.5764,
21.8523, 22.1284]

const theta_single = [1.19209e-7, 0.000597886, 0.0112339, 0.0511662, 0.130849, 0.249529,
0.401458, 0.580052, 0.779511, 0.995184, 1.22348, 1.46166, 1.70765,
1.95985, 2.21704, 2.47828, 2.74282, 3.01007, 3.27956, 3.55093,
3.82386, 4.09811, 4.37347, 4.64978, 4.9269, 5.20471, 5.48311, 5.76201,
6.04136, 6.32108, 6.60113, 6.88146, 7.16204, 7.44283, 7.7238, 8.00493,
8.2862, 8.56759, 8.84908, 9.13065, 9.4123, 9.69402, 9.97579, 10.2576,
10.5394, 10.8213, 11.1032, 11.3852, 11.6671, 11.949, 12.231, 12.5129,
12.7949, 13.0769, 13.3588, 13.6407, 13.9227, 14.2046, 14.4865, 14.7684]

const theta_half = [0.00195058, 0.0744366, 0.266455, 0.524205, 0.810269, 1.10823,
1.41082, 1.71493, 2.01903, 2.32247, 2.62492, 2.9263, 3.22657, 3.52578,
3.82398, 4.12123, 4.41759, 4.71314, 5.00792, 5.302, 5.59543, 5.88825,
6.18051, 6.47224, 6.76348, 7.05427, 7.34464, 7.6346, 7.92419, 8.21342,
8.50232, 8.79091, 9.07921, 9.36722, 9.65497, 9.94247, 10.2297, 10.5168,
10.8036, 11.0902, 11.3766, 11.6629, 11.9489, 12.2348, 12.5205, 12.8061,
13.0915, 13.3768, 13.6619, 13.9469, 14.2318, 14.5165, 14.8012, 15.0857,
15.3702, 15.6547, 15.9391, 16.2235, 16.5078, 16.792, 17.0761, 17.3599,
17.6437, 17.9273, 18.2108, 18.4943, 18.7776, 19.0609, 19.3442, 19.6273,
19.9104, 20.1935, 20.4764, 20.7593, 21.0422, 21.325, 21.6077, 21.8904,
22.173, 22.4556, 22.7381, 23.0206, 23.303, 23.5854, 23.8677, 24.15,
24.4322, 24.7144, 24.9966, 25.2787, 25.5608, 25.8428, 26.1248, 26.4068,
26.6887, 26.9706, 27.2524, 27.5342, 27.816, 28.0978]

function select_taylor_degree(A,
                              b;
                              m_max = 55,
                              p_max = 8,
                              precision = "double",
                              shift = false,
                              # bal,
                              force_estm = false)

    #SELECT_TAYLOR_DEGREE   Select degree of Taylor approximation.
    #   [M,MV,alpha,unA] = SELECT_TAYLOR_DEGREE(A,m_max,p_max) forms a matrix M
    #   for use in determining the truncated Taylor series degree in EXPMV
    #   and EXPMV_TSPAN, based on parameters m_max and p_max.
    #   MV is the number of matrix-vector products with A or A^* computed.

    #   Reference: A. H. Al-Mohy and N. J. Higham, Computing the action of
    #   the matrix exponential, with an application to exponential
    #   integrators. MIMS EPrint 2010.30, The University of Manchester, 2010.

    #   Awad H. Al-Mohy and Nicholas J. Higham, October 26, 2010.

    n = size(A, 1)

    if p_max < 2 || m_max > 60 || m_max + 1 < p_max*(p_max - 1)
        error("Invalid p_max or m_max.")
    end


    theta =
      if precision == "double"
          theta_double
      elseif precision == "single"
          theta_single #load theta_taylor_single
      elseif precision == "half"
          theta_half
      end

    if shift
        mu = tr(A)/n
        A -= mu * I
    end

    if !force_estm
        normA = opnorm(A,1)
    end

    if !force_estm && normA <= 4*theta[m_max]*p_max*(p_max + 3)/(m_max*size(b,2))
        unA = 1
        c = normA
        alpha = c*ones(p_max-1,1)
    else
        unA = 0
        eta = zeros(p_max, 1)
        alpha = zeros(p_max-1, 1)
        for p = 1:p_max
            c = normAm(A, p + 1)
            c = c^(1 / (p + 1))
            eta[p] = c
        end
        for p = 1:p_max-1
            alpha[p] = max(eta[p],eta[p+1])
        end
    end

    M = zeros(m_max,p_max-1)
    for p = 2:p_max
        for m = p*(p-1)-1 : m_max
            M[m,p-1] = alpha[p-1]/theta[m]
        end
    end
    return (M,alpha,unA)

end
