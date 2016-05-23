!! program to calculate DELTA_(VARIABLE) for density, velocity, curvature, and also to reconstruct phi including phi_x files at each chosen timestep
!! REQUIRES FILES: --> velocity_*, density_*, curv_*, metric_*
program deltavel
  implicit none

  integer, parameter:: dp=8, n=int(1e5)
  integer:: i,q,b, p,number,npts, j, itmin, it, l, dit, m, dt, res
  real(dp):: vel_120, vel_zero, rho_120, rho_zero, dum, deltav, deltarho, curv_zero, s, t
  real(dp), parameter:: pi=3.141592653589793238462643383279502884197, rho0=1.e-8, a0=1.
  real(dp), allocatable, dimension(:):: vel_x, x, rho_x, curv_x, gxx_x, phi_x
  real(dp):: a, phi_zero, phi_120, curv_120, deltaphi, deltacurv
  character(len=40):: file_vel, file_rho, file_curv, file_metric, file_phi
  integer:: header

  print*,'Look at every nth iteration, enter n:'
  read(*,*) number

  print*,'Enter resolution of run:'
  read(*,*) res
  npts = 480 / res ! number of grid points based on resolution

  allocate(vel_x(npts),x(npts),rho_x(npts),curv_x(npts),gxx_x(npts),phi_x(npts))

  print*,'Are there headers in your files? 1=yes, 2=no'
  read(*,*) header

  m = 100
  p = 1000
  q = 500
  b = 700
  dit = 512
  itmin = 0
  dt = 2.4_dp
!  number = 100 ! read every 'number'th file

! open file to write deltas, evolution of other variables to
  open(unit=10, file='delta_vals.out', status='replace')
  write(10,*) '# s        deltarho           deltav           curv_zero        deltacurv           deltaphi         phi_zero'

  do i=1,n+1
! integers for file opening/writing
     m = m+1
     p = p+1
     q = q+1
     b = b+1

! calculate iteration
     if (i==1) then
        it = itmin
     else
        it = itmin + ((i-1)*dit*number - dit)
     endif

! open pre-existing files made from file-splitter.pl
     write(file_vel,'(a,i9.9,a)')'velocity_',it,'.dat'
     open(unit=m,file=file_vel,status='old')
     write(file_rho,'(a,i9.9,a)')'density_',it,'.dat'
     open(unit=p,file=file_rho,status='old')
     write(file_curv,'(a,i9.9,a)')'curv_',it,'.dat'
     open(unit=q,file=file_curv,status='old')
     write(file_metric,'(a,i9.9,a)')'metric_',it,'.dat'
     open(unit=b,file=file_metric,status='old')

     if (header==1) then
        do j=1,6 ! read out headers from regular file splitter
           read(m,*)
           read(p,*)
           read(q,*)
           read(b,*)
        enddo
     else ! read out timestamp line on files from mpi file splitter
        read(m,*)
        read(p,*)
        read(q,*)
        read(b,*)
     endif


! loop over x-files and save values of some things at x=0, x=120 (max/avg values)
     do j=1,npts
        read(m,*) (dum,l=1,8), t, x(j), dum, dum, vel_x(j)
        read(p,*) (dum,l=1,12), rho_x(j)
        read(q,*) (dum,l=1,12), curv_x(j)
        read(b,*) (dum,l=1,12), gxx_x(j)
        if (x(j)==0) then
           vel_zero = vel_x(j)
           rho_zero = rho_x(j)
           curv_zero = curv_x(j)
        elseif (x(j)==120) then
           vel_120 = vel_x(j)
           rho_120 = rho_x(j)
           curv_120 = curv_x(j)
        endif
     enddo

! calculate scaled time 's' and exact FLRW scale factor 'a'
     s = 1._dp + sqrt(6._dp * pi * rho0) * t
     a = a0 * s**(2._dp/3._dp)
     
! open and write to phi as a function of x file (reconstructed from gxx_x)
     write(file_phi,'(a,i9.9,a)')'phix_',it,'.dat'
     open(unit=b+1,file=file_phi,status='replace')
     do j=1,npts
        phi_x(j) = 0.5_dp * (1._dp - gxx_x(j) / a**2)
        if (x(j)==0) then
           phi_zero = phi_x(j)
        elseif (x(j)==120) then
           phi_120 = phi_x(j)
        endif
        write(b+1,*) x(j), phi_x(j)
     enddo

! calculate delta in velocity and density as difference between location of max and avg values
     deltav = abs(vel_zero - vel_120)
     deltarho = abs(rho_zero - rho_120) / abs(rho_zero)
     deltaphi = abs(phi_zero - phi_120)
     deltacurv = abs(curv_zero - curv_120) / abs(curv_zero)

! write to delta_vals file
     print*,'ITERATION is',it
     write(10,*) s, deltarho, deltav, abs(curv_zero), deltacurv, deltaphi, phi_zero
     
     close(m)
     close(p)
     close(q)
     close(b)
     close(b+1)
  enddo
print*, 'DONE: written evolution of deltas, curv, phi to delta_vals.out'
print*, 'written reconstructed phi as a function of x to phix_* files'

end program deltavel
     