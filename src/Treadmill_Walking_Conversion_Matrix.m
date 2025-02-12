function A = Treadmill_Walking_Conversion_Matrix(p, sensor_rot)

%
% Treadmill_Walking_Conversion_Matrix.m - Vulintus, Inc.
%
%   TREADMILL_WALKING_CONVERSION_MATRIX creates the conversion matrix for
%   translating the MotoTrak Spherical Treadmill's optical mouse sensor
%   readings into 3-dimensional angular velocity. The input arguments are
%   as follows:
%
%       pos        = 3x3 matrix of spherical coordinate position vectors
%                    (theta, phi, radius), in which each row is the 
%                    position vector for one velocity reading. In Vulintus 
%                    convention, the first 2 readings come from sensor #1
%                    (x and y), and so should be identical, and the third 
%                    reading comes from sensor #2 (x only). Angle values 
%                    "theta" and "phi" should be in degrees.
%       sensor_rot = Angle of the sensor's x-axis relative to the azimuthal
%                    plane of the sphere. Assume all sensors have the same
%                    orientation.
%
%   These calculations are based the system described by Kumagai & Hollis,
%   2011, "Development of a three-dimensional ball rotation sensing system
%   using optical mouse sensors."
%   
%   UPDATE LOG:
%   2025-02-07 - Drew Sloan - Function first created
%

s = [   1,  0,  0;                                                          %Sensor #1's x axis.
        0,  1,  0;                                                          %Sensor #1's y axis.
        1,  0,  0 ;                                                         %Sensor #2's x axis.
    ];                                                                      %Create unit vectors for the sensor vectors.


%Rotate the sensor coordinate systems about their z-axes to align their
%x-axis to the azimuthal plane.
R = rotation_matrix_3d(0, 0, sensor_rot);                                   %Create a 3D rotation matrix.
for i = 1:3                                                                 %Step through the unit vectors.
    s(i,:) = s(i,:)' \ R;                                                   %Apply the rotation matrix to each unit vector.
end

%Rotate the sensor coordinate systems about their y-axes to make their x-y
%planes parallel to the sphere's x-y plane.
for i = 1:3                                                                 %Step through the unit vectors.
    R = rotation_matrix_3d(0, p(i,2), 0);                                   %Create a 3D rotation matrix.
    s(i,:) = s(i,:)' \ R;                                                   %Apply the rotation matrix to each unit vector.
end

%Rotate the sensor coordinate systems about their z-axes again to align
%their x-axes parallel to the sphere's x-axis.
for i = 1:3                                                                 %Step through the unit vectors.
    R = rotation_matrix_3d(0, 0, 180-p(i,1));                               %Create a 3D rotation matrix.
    s(i,:) = s(i,:)' \ R;                                                   %Apply the rotation matrix to each unit vector.
end                                     

%Convert the spherical coordinates of the sensor positions into cartesian
%coordinates.
p(:,1:2) = deg2rad(p(:,1:2));                                               %Convert the coordinate theta and phi values to radians.
[p(:,1), p(:,2), p(:,3)] = sph2cart(p(:,1), p(:,2), p(:,3));                %Convert the spherical coordinates to cartesian.

%Find the cross product of each position vector with it's correspond
%velocity unit vector.
A = zeros(3,3);                                                             %Pre-allocate an array.
for i = 1:3                                                                 %Step through each unit vector.
    A(i,:) = cross(p(i,:),s(i,:));                                          %Calculate the cross product.
end

%The conversion matrix is the inverse of A.
A = inv(A);

%Now, with the conversion matrix set, we can determine the angular velocity
%of the sphere, w(i,j,k), from the velocities measured at the sensors,
%v(i,j,k).
%   w(i,j,k) = A * v(i,j,l);








