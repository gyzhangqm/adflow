   !        Generated by TAPENADE     (INRIA, Tropics team)
   !  Tapenade 3.6 (r4159) - 21 Sep 2011 10:11
   !
   !  Differentiation of gridvelocitiesfinelevel_block in forward (tangent) mode:
   !   variations   of useful results: *sfacei *sfacej *s *sfacek
   !   with respect to varying inputs: omegafourbeta *coscoeffourmach
   !                *coefpolbeta *coscoeffouralpha rotpoint *coscoeffourbeta
   !                omegafourxrot *sincoeffourmach *coefpolalpha omegafouryrot
   !                omegafourzrot omegafouralpha omegafourmach *coefpolmach
   !                *sincoeffourbeta *sincoeffouralpha *x *si *sj
   !                *sk *coeftime deltat *cgnsdoms.rotcenter *cgnsdoms.rotrate
   !   Plus diff mem management of: coscoeffourzrot:in sincoeffourxrot:in
   !                sincoeffouryrot:in sincoeffourzrot:in coefpolxrot:in
   !                coefpolyrot:in coefpolzrot:in coscoeffourxrot:in
   !                coscoeffouryrot:in sfacei:in sfacej:in s:in sfacek:in
   !                x:in si:in sj:in sk:in coeftime:in
   !
   !      ******************************************************************
   !      *                                                                *
   !      * File:          gridVelocities_block.f90                        *
   !      * Author:        Edwin van der Weide,C.A.(Sandy) Mader           *
   !      * Starting date: 07-15-2011                                      *
   !      * Last modified: 07-15-2011                                      *
   !      *                                                                *
   !      ******************************************************************
   !
   SUBROUTINE GRIDVELOCITIESFINELEVEL_BLOCK_D(useoldcoor, t, sps)
   USE FLOWVARREFSTATE
   USE MONITOR
   USE CGNSGRID
   USE BLOCKPOINTERS_D
   USE INPUTTSSTABDERIV
   USE INPUTUNSTEADY
   USE INPUTPHYSICS
   USE COMMUNICATION
   USE ITERATION
   USE INPUTMOTION
   IMPLICIT NONE
   !
   !      ******************************************************************
   !      *                                                                *
   !      * gridVelocitiesFineLevel computes the grid velocities for       *
   !      * the cell centers and the normal grid velocities for the faces  *
   !      * of moving blocks for the currently finest grid, i.e.           *
   !      * groundLevel. The velocities are computed at time t for         *
   !      * spectral mode sps. If useOldCoor is .true. the velocities      *
   !      * are determined using the unsteady time integrator in           *
   !      * combination with the old coordinates; otherwise the analytic   *
   !      * form is used. This routine is setup to operate on only a       *
   !      * single block for the forward mode AD.                           *
   !      *                                                                *
   !      ******************************************************************
   !
   !
   !      Subroutine arguments.
   !
   INTEGER(kind=inttype), INTENT(IN) :: sps
   LOGICAL, INTENT(IN) :: useoldcoor
   REAL(kind=realtype), DIMENSION(*), INTENT(IN) :: t
   !
   !      Local variables.
   !
   INTEGER(kind=inttype) :: mm
   INTEGER(kind=inttype) :: i, j, k, ii, iie, jje, kke
   REAL(kind=realtype) :: oneover4dt, oneover8dt
   REAL(kind=realtype) :: velxgrid, velygrid, velzgrid, ainf
   REAL(kind=realtype) :: velxgrid0, velygrid0, velzgrid0
   REAL(kind=realtype), DIMENSION(3) :: sc, xc, xxc
   REAL(kind=realtype), DIMENSION(3) :: scd, xcd, xxcd
   REAL(kind=realtype), DIMENSION(3) :: rotcenter, rotrate
   REAL(kind=realtype), DIMENSION(3) :: rotrated
   REAL(kind=realtype), DIMENSION(3) :: rotratetemp
   REAL(kind=realtype), DIMENSION(3) :: offsetvector
   REAL(kind=realtype), DIMENSION(3, 3) :: rotratetrans
   REAL(kind=realtype), DIMENSION(3, 3) :: rotratetransd
   REAL(kind=realtype), DIMENSION(3) :: rotationpoint
   REAL(kind=realtype), DIMENSION(3, 3) :: rotationmatrix, &
   &  derivrotationmatrix
   REAL(kind=realtype) :: tnew, told
   REAL(kind=realtype), DIMENSION(:, :), POINTER :: sface
   REAL(kind=realtype), DIMENSION(:, :), POINTER :: sfaced
   REAL(kind=realtype), DIMENSION(:, :, :), POINTER :: xx, ss
   REAL(kind=realtype), DIMENSION(:, :, :), POINTER :: xxd, ssd
   REAL(kind=realtype), DIMENSION(:, :, :, :), POINTER :: xxold
   INTEGER(kind=inttype) :: liftindex
   REAL(kind=realtype) :: alpha, beta, intervalmach, alphats, &
   &  alphaincrement, betats, betaincrement
   REAL(kind=realtype), DIMENSION(3) :: veldir, liftdir, dragdir
   !Function Definitions
   REAL(kind=realtype) :: TSALPHA, TSBETA, TSMACH
   REAL(kind=realtype) :: arg1
   INTRINSIC COS
   INTRINSIC SIN
   INTRINSIC SQRT
   !
   !      ******************************************************************
   !      *                                                                *
   !      * Begin execution                                                *
   !      *                                                                *
   !      ******************************************************************
   !
   ! Compute the mesh velocity from the given mesh Mach number.
   !  aInf = sqrt(gammaInf*pInf/rhoInf)
   !  velxGrid = aInf*MachGrid(1)
   !  velyGrid = aInf*MachGrid(2)
   !  velzGrid = aInf*MachGrid(3)
   !print *,'machgrid',machgrid
   !stop
   !velxGrid = zero
   !velyGrid = zero
   !velzGrid = zero
   arg1 = gammainf*pinf/rhoinf
   ainf = SQRT(arg1)
   velxgrid0 = ainf*machgrid*(-veldirfreestream(1))
   velygrid0 = ainf*machgrid*(-veldirfreestream(2))
   velzgrid0 = ainf*machgrid*(-veldirfreestream(3))
   ! Compute the derivative of the rotation matrix and the rotation
   ! point; needed for velocity due to the rigid body rotation of
   ! the entire grid. It is assumed that the rigid body motion of
   ! the grid is only specified if there is only 1 section present.
   CALL DERIVATIVEROTMATRIXRIGID(derivrotationmatrix, rotationpoint, t&
   &                             (1))
   !print *,'rotation Matrix'!,derivRotationMatrix, rotationPoint,'t', t(1)
   !compute the rotation matrix to update the velocities for the time
   !spectral stability derivative case...
   IF (tsstability) THEN
   ! Determine the time values of the old and new time level.
   ! It is assumed that the rigid body rotation of the mesh is only
   ! used when only 1 section is present.
   tnew = timeunsteady + timeunsteadyrestart
   told = tnew - t(1)
   IF ((tspmode .OR. tsqmode) .OR. tsrmode) THEN
   ! Compute the rotation matrix of the rigid body rotation as
   ! well as the rotation point; the latter may vary in time due
   ! to rigid body translation.
   CALL ROTMATRIXRIGIDBODY(tnew, told, rotationmatrix, &
   &                           rotationpoint)
   velxgrid0 = rotationmatrix(1, 1)*velxgrid0 + rotationmatrix(1, 2)*&
   &        velygrid0 + rotationmatrix(1, 3)*velzgrid0
   velygrid0 = rotationmatrix(2, 1)*velxgrid0 + rotationmatrix(2, 2)*&
   &        velygrid0 + rotationmatrix(2, 3)*velzgrid0
   velzgrid0 = rotationmatrix(3, 1)*velxgrid0 + rotationmatrix(3, 2)*&
   &        velygrid0 + rotationmatrix(3, 3)*velzgrid0
   ELSE IF (tsalphamode) THEN
   ! get the baseline alpha and determine the liftIndex
   CALL GETDIRANGLE(veldirfreestream, liftdirection, liftindex, &
   &                    alpha, beta)
   !Determine the alpha for this time instance
   alphaincrement = TSALPHA(degreepolalpha, coefpolalpha, &
   &        degreefouralpha, omegafouralpha, coscoeffouralpha, &
   &        sincoeffouralpha, t(1))
   alphats = alpha + alphaincrement
   !Determine the grid velocity for this alpha
   CALL ADJUSTINFLOWANGLEADJ(alphats, beta, veldir, liftdir, &
   &                             dragdir, liftindex)
   !do I need to update the lift direction and drag direction as well?
   !set the effictive grid velocity for this time interval
   velxgrid0 = ainf*machgrid*(-veldir(1))
   velygrid0 = ainf*machgrid*(-veldir(2))
   velzgrid0 = ainf*machgrid*(-veldir(3))
   ! if (myid ==0) print *,'base velocity',machgrid, velxGrid0 , velyGrid0 , velzGrid0 
   ELSE IF (tsbetamode) THEN
   ! get the baseline alpha and determine the liftIndex
   CALL GETDIRANGLE(veldirfreestream, liftdirection, liftindex, &
   &                    alpha, beta)
   !Determine the alpha for this time instance
   betaincrement = TSBETA(degreepolbeta, coefpolbeta, &
   &        degreefourbeta, omegafourbeta, coscoeffourbeta, sincoeffourbeta&
   &        , t(1))
   betats = beta + betaincrement
   !Determine the grid velocity for this alpha
   CALL ADJUSTINFLOWANGLEADJ(alpha, betats, veldir, liftdir, &
   &                             dragdir, liftindex)
   !do I need to update the lift direction and drag direction as well?
   !set the effictive grid velocity for this time interval
   velxgrid0 = ainf*machgrid*(-veldir(1))
   velygrid0 = ainf*machgrid*(-veldir(2))
   velzgrid0 = ainf*machgrid*(-veldir(3))
   ELSE IF (tsmachmode) THEN
   !determine the mach number at this time interval
   intervalmach = TSMACH(degreepolmach, coefpolmach, &
   &        degreefourmach, omegafourmach, coscoeffourmach, sincoeffourmach&
   &        , t(1))
   !set the effective grid velocity
   velxgrid0 = ainf*(intervalmach+machgrid)*(-veldirfreestream(1))
   velygrid0 = ainf*(intervalmach+machgrid)*(-veldirfreestream(2))
   velzgrid0 = ainf*(intervalmach+machgrid)*(-veldirfreestream(3))
   ELSE IF (tsaltitudemode) THEN
   CALL TERMINATE('gridVelocityFineLevel', &
   &                  'altitude motion not yet implemented...')
   ELSE
   CALL TERMINATE('gridVelocityFineLevel', &
   &                  'Not a recognized Stability Motion')
   END IF
   END IF
   IF (blockismoving) THEN
   ! print *,'block is moving',blockIsMoving,useOldCoor 
   ! Determine the situation we are having here.
   IF (useoldcoor) THEN
   !
   !            ************************************************************
   !            *                                                          *
   !            * The velocities must be determined via a finite           *
   !            * difference formula using the coordinates of the old      *
   !            * levels.                                                  *
   !            *                                                          *
   !            ************************************************************
   !
   ! Set the coefficients for the time integrator and store
   ! the inverse of the physical nonDimensional time step,
   ! divided by 4 and 8, a bit easier.
   CALL SETCOEFTIMEINTEGRATOR()
   oneover4dt = fourth*timeref/deltat
   oneover8dt = half*oneover4dt
   sd = 0.0
   scd = 0.0
   !
   !            ************************************************************
   !            *                                                          *
   !            * Grid velocities of the cell centers, including the       *
   !            * 1st level halo cells.                                    *
   !            *                                                          *
   !            ************************************************************
   !
   ! Loop over the cells, including the 1st level halo's.
   DO k=1,ke
   DO j=1,je
   DO i=1,ie
   ! The velocity of the cell center is determined
   ! by a finite difference formula. First store
   ! the current coordinate, multiplied by 8 and
   ! coefTime(0) in sc.
   scd(1) = coeftime(0)*(xd(i-1, j-1, k-1, 1)+xd(i, j-1, k-1, 1&
   &              )+xd(i-1, j, k-1, 1)+xd(i, j, k-1, 1)+xd(i-1, j-1, k, 1)+&
   &              xd(i, j-1, k, 1)+xd(i-1, j, k, 1)+xd(i, j, k, 1))
   sc(1) = (x(i-1, j-1, k-1, 1)+x(i, j-1, k-1, 1)+x(i-1, j, k-1&
   &              , 1)+x(i, j, k-1, 1)+x(i-1, j-1, k, 1)+x(i, j-1, k, 1)+x(i&
   &              -1, j, k, 1)+x(i, j, k, 1))*coeftime(0)
   scd(2) = coeftime(0)*(xd(i-1, j-1, k-1, 2)+xd(i, j-1, k-1, 2&
   &              )+xd(i-1, j, k-1, 2)+xd(i, j, k-1, 2)+xd(i-1, j-1, k, 2)+&
   &              xd(i, j-1, k, 2)+xd(i-1, j, k, 2)+xd(i, j, k, 2))
   sc(2) = (x(i-1, j-1, k-1, 2)+x(i, j-1, k-1, 2)+x(i-1, j, k-1&
   &              , 2)+x(i, j, k-1, 2)+x(i-1, j-1, k, 2)+x(i, j-1, k, 2)+x(i&
   &              -1, j, k, 2)+x(i, j, k, 2))*coeftime(0)
   scd(3) = coeftime(0)*(xd(i-1, j-1, k-1, 3)+xd(i, j-1, k-1, 3&
   &              )+xd(i-1, j, k-1, 3)+xd(i, j, k-1, 3)+xd(i-1, j-1, k, 3)+&
   &              xd(i, j-1, k, 3)+xd(i-1, j, k, 3)+xd(i, j, k, 3))
   sc(3) = (x(i-1, j-1, k-1, 3)+x(i, j-1, k-1, 3)+x(i-1, j, k-1&
   &              , 3)+x(i, j, k-1, 3)+x(i-1, j-1, k, 3)+x(i, j-1, k, 3)+x(i&
   &              -1, j, k, 3)+x(i, j, k, 3))*coeftime(0)
   ! Loop over the older levels to complete the
   ! finite difference formula.
   DO ii=1,noldlevels
   sc(1) = sc(1) + (xold(ii, i-1, j-1, k-1, 1)+xold(ii, i, j-&
   &                1, k-1, 1)+xold(ii, i-1, j, k-1, 1)+xold(ii, i, j, k-1, &
   &                1)+xold(ii, i-1, j-1, k, 1)+xold(ii, i, j-1, k, 1)+xold(&
   &                ii, i-1, j, k, 1)+xold(ii, i, j, k, 1))*coeftime(ii)
   sc(2) = sc(2) + (xold(ii, i-1, j-1, k-1, 2)+xold(ii, i, j-&
   &                1, k-1, 2)+xold(ii, i-1, j, k-1, 2)+xold(ii, i, j, k-1, &
   &                2)+xold(ii, i-1, j-1, k, 2)+xold(ii, i, j-1, k, 2)+xold(&
   &                ii, i-1, j, k, 2)+xold(ii, i, j, k, 2))*coeftime(ii)
   sc(3) = sc(3) + (xold(ii, i-1, j-1, k-1, 3)+xold(ii, i, j-&
   &                1, k-1, 3)+xold(ii, i-1, j, k-1, 3)+xold(ii, i, j, k-1, &
   &                3)+xold(ii, i-1, j-1, k, 3)+xold(ii, i, j-1, k, 3)+xold(&
   &                ii, i-1, j, k, 3)+xold(ii, i, j, k, 3))*coeftime(ii)
   END DO
   ! Divide by 8 delta t to obtain the correct
   ! velocities.
   sd(i, j, k, 1) = oneover8dt*scd(1)
   s(i, j, k, 1) = sc(1)*oneover8dt
   sd(i, j, k, 2) = oneover8dt*scd(2)
   s(i, j, k, 2) = sc(2)*oneover8dt
   sd(i, j, k, 3) = oneover8dt*scd(3)
   s(i, j, k, 3) = sc(3)*oneover8dt
   END DO
   END DO
   END DO
   sfaceid = 0.0
   sfacejd = 0.0
   sfacekd = 0.0
   !
   !            ************************************************************
   !            *                                                          *
   !            * Normal grid velocities of the faces.                     *
   !            *                                                          *
   !            ************************************************************
   !
   ! Loop over the three directions.
   loopdir:DO mm=1,3
   ! Set the upper boundaries depending on the direction.
   SELECT CASE  (mm) 
   CASE (1_intType) 
   ! normals in i-direction
   iie = ie
   jje = je
   kke = ke
   CASE (2_intType) 
   ! normals in j-direction
   iie = je
   jje = ie
   kke = ke
   CASE (3_intType) 
   ! normals in k-direction
   iie = ke
   jje = ie
   kke = je
   END SELECT
   !
   !              **********************************************************
   !              *                                                        *
   !              * Normal grid velocities in generalized i-direction.     *
   !              * Mm == 1: i-direction                                   *
   !              * mm == 2: j-direction                                   *
   !              * mm == 3: k-direction                                   *
   !              *                                                        *
   !              **********************************************************
   !
   DO i=0,iie
   ! Set the pointers for the coordinates, normals and
   ! normal velocities for this generalized i-plane.
   ! This depends on the value of mm.
   SELECT CASE  (mm) 
   CASE (1_intType) 
   ! normals in i-direction
   xxd => xd(i, :, :, :)
   xx => x(i, :, :, :)
   xxold => xold(:, i, :, :, :)
   ssd => sid(i, :, :, :)
   ss => si(i, :, :, :)
   sfaced => sfaceid(i, :, :)
   sface => sfacei(i, :, :)
   CASE (2_intType) 
   ! normals in j-direction
   xxd => xd(:, i, :, :)
   xx => x(:, i, :, :)
   xxold => xold(:, :, i, :, :)
   ssd => sjd(:, i, :, :)
   ss => sj(:, i, :, :)
   sfaced => sfacejd(:, i, :)
   sface => sfacej(:, i, :)
   CASE (3_intType) 
   ! normals in k-direction
   xxd => xd(:, :, i, :)
   xx => x(:, :, i, :)
   xxold => xold(:, :, :, i, :)
   ssd => skd(:, :, i, :)
   ss => sk(:, :, i, :)
   sfaced => sfacekd(:, :, i)
   sface => sfacek(:, :, i)
   END SELECT
   ! Loop over the k and j-direction of this
   ! generalized i-face. Note that due to the usage of
   ! the pointers xx and xxOld an offset of +1 must be
   ! used in the coordinate arrays, because x and xOld
   ! originally start at 0 for the i, j and k indices.
   DO k=1,kke
   DO j=1,jje
   ! The velocity of the face center is determined
   ! by a finite difference formula. First store
   ! the current coordinate, multiplied by 4 and
   ! coefTime(0) in sc.
   scd(1) = coeftime(0)*(xxd(j+1, k+1, 1)+xxd(j, k+1, 1)+xxd(&
   &                j+1, k, 1)+xxd(j, k, 1))
   sc(1) = coeftime(0)*(xx(j+1, k+1, 1)+xx(j, k+1, 1)+xx(j+1&
   &                , k, 1)+xx(j, k, 1))
   scd(2) = coeftime(0)*(xxd(j+1, k+1, 2)+xxd(j, k+1, 2)+xxd(&
   &                j+1, k, 2)+xxd(j, k, 2))
   sc(2) = coeftime(0)*(xx(j+1, k+1, 2)+xx(j, k+1, 2)+xx(j+1&
   &                , k, 2)+xx(j, k, 2))
   scd(3) = coeftime(0)*(xxd(j+1, k+1, 3)+xxd(j, k+1, 3)+xxd(&
   &                j+1, k, 3)+xxd(j, k, 3))
   sc(3) = coeftime(0)*(xx(j+1, k+1, 3)+xx(j, k+1, 3)+xx(j+1&
   &                , k, 3)+xx(j, k, 3))
   ! Loop over the older levels to complete the
   ! finite difference.
   DO ii=1,noldlevels
   sc(1) = sc(1) + coeftime(ii)*(xxold(ii, j+1, k+1, 1)+&
   &                  xxold(ii, j, k+1, 1)+xxold(ii, j+1, k, 1)+xxold(ii, j&
   &                  , k, 1))
   sc(2) = sc(2) + coeftime(ii)*(xxold(ii, j+1, k+1, 2)+&
   &                  xxold(ii, j, k+1, 2)+xxold(ii, j+1, k, 2)+xxold(ii, j&
   &                  , k, 2))
   sc(3) = sc(3) + coeftime(ii)*(xxold(ii, j+1, k+1, 3)+&
   &                  xxold(ii, j, k+1, 3)+xxold(ii, j+1, k, 3)+xxold(ii, j&
   &                  , k, 3))
   END DO
   ! Determine the dot product of sc and the normal
   ! and divide by 4 deltaT to obtain the correct
   ! value of the normal velocity.
   sfaced(j, k) = scd(1)*ss(j, k, 1) + sc(1)*ssd(j, k, 1) + &
   &                scd(2)*ss(j, k, 2) + sc(2)*ssd(j, k, 2) + scd(3)*ss(j, k&
   &                , 3) + sc(3)*ssd(j, k, 3)
   sface(j, k) = sc(1)*ss(j, k, 1) + sc(2)*ss(j, k, 2) + sc(3&
   &                )*ss(j, k, 3)
   sfaced(j, k) = oneover4dt*sfaced(j, k)
   sface(j, k) = sface(j, k)*oneover4dt
   END DO
   END DO
   END DO
   END DO loopdir
   ELSE
   !
   !            ************************************************************
   !            *                                                          *
   !            * The velocities must be determined analytically.          *
   !            *                                                          *
   !            ************************************************************
   !
   ! Store the rotation center and determine the
   ! nonDimensional rotation rate of this block. As the
   ! reference length is 1 timeRef == 1/uRef and at the end
   ! the nonDimensional velocity is computed.
   j = nbkglobal
   rotcenter = cgnsdoms(j)%rotcenter
   !if (myid==0)print *,'rotcenter',rotCenter,'rotpoint',rotpoint
   !offSetVector= (rotCenter-pointRef)
   offsetvector = rotcenter - rotpoint
   !if (myid==0)print *,'offset vector',offSetVector, rotCenter,pointRef
   rotrate = timeref*cgnsdoms(j)%rotrate
   !if (myid==0) print *,'rotrate, gridvelocity',rotRate,cgnsDoms(j)%rotRate
   IF (usewindaxis) THEN
   !determine the current angles from the free stream velocity
   CALL GETDIRANGLE(veldirfreestream, liftdirection, liftindex, &
   &                      alpha, beta)
   IF (liftindex .EQ. 2) THEN
   ! different coordinate system for aerosurf
   ! Wing is in z- direction
   rotratetransd(1, 1) = 0.0
   rotratetrans(1, 1) = COS(alpha)*COS(beta)
   rotratetransd(1, 2) = 0.0
   rotratetrans(1, 2) = -SIN(alpha)
   rotratetransd(1, 3) = 0.0
   rotratetrans(1, 3) = -(COS(alpha)*SIN(beta))
   rotratetransd(2, 1) = 0.0
   rotratetrans(2, 1) = SIN(alpha)*COS(beta)
   rotratetransd(2, 2) = 0.0
   rotratetrans(2, 2) = COS(alpha)
   rotratetransd(2, 3) = 0.0
   rotratetrans(2, 3) = -(SIN(alpha)*SIN(beta))
   rotratetransd(3, 1) = 0.0
   rotratetrans(3, 1) = SIN(beta)
   rotratetransd(3, 2) = 0.0
   rotratetrans(3, 2) = 0.0
   rotratetransd(3, 3) = 0.0
   rotratetrans(3, 3) = COS(beta)
   ELSE IF (liftindex .EQ. 3) THEN
   ! Wing is in y- direction
   !Rotate the rotation rate from the wind axis back to the local body axis
   rotratetransd(1, 1) = 0.0
   rotratetrans(1, 1) = COS(alpha)*COS(beta)
   rotratetransd(1, 2) = 0.0
   rotratetrans(1, 2) = -(COS(alpha)*SIN(beta))
   rotratetransd(1, 3) = 0.0
   rotratetrans(1, 3) = -SIN(alpha)
   rotratetransd(2, 1) = 0.0
   rotratetrans(2, 1) = SIN(beta)
   rotratetransd(2, 2) = 0.0
   rotratetrans(2, 2) = COS(beta)
   rotratetransd(2, 3) = 0.0
   rotratetrans(2, 3) = 0.0
   rotratetransd(3, 1) = 0.0
   rotratetrans(3, 1) = SIN(alpha)*COS(beta)
   rotratetransd(3, 2) = 0.0
   rotratetrans(3, 2) = -(SIN(alpha)*SIN(beta))
   rotratetransd(3, 3) = 0.0
   rotratetrans(3, 3) = COS(alpha)
   ELSE
   CALL TERMINATE('getDirAngle', 'Invalid Lift Direction')
   END IF
   rotratetemp = rotrate
   rotrate = 0.0
   DO i=1,3
   DO j=1,3
   rotrated(i) = 0.0
   rotrate(i) = rotrate(i) + rotratetemp(j)*rotratetrans(i, j)
   END DO
   END DO
   END IF
   ! if (nn==1) then
   !    print *,'rotRate',rotRate/timeref,'timeref',timeref
   ! endif
   !!$             if (useWindAxis)then
   !!$                !determine the current angles from the free stream velocity
   !!$                call getDirAngle(velDirFreestream,liftDirection,liftIndex,alpha,beta)
   !!$                !Rotate the rotation rate from the wind axis back to the local body axis
   !!$                !checkt he relationship between the differnt degrees of freedom!
   !!$                rotRateTrans(1,1)=cos(alpha)*cos(beta)
   !!$                rotRateTrans(1,2)=-cos(alpha)*sin(beta)
   !!$                rotRateTrans(1,3)=-sin(alpha)
   !!$                rotRateTrans(2,1)=sin(beta)
   !!$                rotRateTrans(2,2)=cos(beta)
   !!$                rotRateTrans(2,3)=0.0
   !!$                rotRateTrans(3,1)=sin(alpha)*cos(beta)
   !!$                rotRateTrans(3,2)=-sin(alpha)*sin(beta)
   !!$                rotRateTrans(3,3)=cos(alpha)
   !!$
   !!$                rotRateTemp = rotRate
   !!$                rotRate=0.0
   !!$                do i=1,3
   !!$                   do j=1,3
   !!$                      rotRate(i)=rotRate(i)+rotRateTemp(j)*rotRateTrans(i,j)
   !!$                   end do
   !!$                end do
   !!$             end if
   !subtract off the rotational velocity of the center of the grid
   ! to account for the added overall velocity.
   !             velxGrid =velxgrid0+ 1*(rotRate(2)*rotCenter(3) - rotRate(3)*rotCenter(2))
   !             velyGrid =velygrid0+ 1*(rotRate(3)*rotCenter(1) - rotRate(1)*rotCenter(3))
   !             velzGrid =velzgrid0+ 1*(rotRate(1)*rotCenter(2) - rotRate(2)*rotCenter(1))
   !if (myid==0) print *,'velocity update',offSetVector,rotPoint,'matrix',derivRotationMatrix
   velxgrid = velxgrid0 + 1*(rotrate(2)*offsetvector(3)-rotrate(3)*&
   &        offsetvector(2)) + derivrotationmatrix(1, 1)*offsetvector(1) + &
   &        derivrotationmatrix(1, 2)*offsetvector(2) + derivrotationmatrix(&
   &        1, 3)*offsetvector(3)
   velygrid = velygrid0 + 1*(rotrate(3)*offsetvector(1)-rotrate(1)*&
   &        offsetvector(3)) + derivrotationmatrix(2, 1)*offsetvector(1) + &
   &        derivrotationmatrix(2, 2)*offsetvector(2) + derivrotationmatrix(&
   &        2, 3)*offsetvector(3)
   velzgrid = velzgrid0 + 1*(rotrate(1)*offsetvector(2)-rotrate(2)*&
   &        offsetvector(1)) + derivrotationmatrix(3, 1)*offsetvector(1) + &
   &        derivrotationmatrix(3, 2)*offsetvector(2) + derivrotationmatrix(&
   &        3, 3)*offsetvector(3)
   sd = 0.0
   xcd = 0.0
   xxcd = 0.0
   scd = 0.0
   !add in rotmatrix*rotpoint....
   !print *,'velgrid',velxGrid,velyGrid , velzGrid
   !
   !            ************************************************************
   !            *                                                          *
   !            * Grid velocities of the cell centers, including the       *
   !            * 1st level halo cells.                                    *
   !            *                                                          *
   !            ************************************************************
   !
   ! Loop over the cells, including the 1st level halo's.
   DO k=1,ke
   DO j=1,je
   DO i=1,ie
   ! Determine the coordinates of the cell center,
   ! which are stored in xc.
   xcd(1) = eighth*(xd(i-1, j-1, k-1, 1)+xd(i, j-1, k-1, 1)+xd(&
   &              i-1, j, k-1, 1)+xd(i, j, k-1, 1)+xd(i-1, j-1, k, 1)+xd(i, &
   &              j-1, k, 1)+xd(i-1, j, k, 1)+xd(i, j, k, 1))
   xc(1) = eighth*(x(i-1, j-1, k-1, 1)+x(i, j-1, k-1, 1)+x(i-1&
   &              , j, k-1, 1)+x(i, j, k-1, 1)+x(i-1, j-1, k, 1)+x(i, j-1, k&
   &              , 1)+x(i-1, j, k, 1)+x(i, j, k, 1))
   xcd(2) = eighth*(xd(i-1, j-1, k-1, 2)+xd(i, j-1, k-1, 2)+xd(&
   &              i-1, j, k-1, 2)+xd(i, j, k-1, 2)+xd(i-1, j-1, k, 2)+xd(i, &
   &              j-1, k, 2)+xd(i-1, j, k, 2)+xd(i, j, k, 2))
   xc(2) = eighth*(x(i-1, j-1, k-1, 2)+x(i, j-1, k-1, 2)+x(i-1&
   &              , j, k-1, 2)+x(i, j, k-1, 2)+x(i-1, j-1, k, 2)+x(i, j-1, k&
   &              , 2)+x(i-1, j, k, 2)+x(i, j, k, 2))
   xcd(3) = eighth*(xd(i-1, j-1, k-1, 3)+xd(i, j-1, k-1, 3)+xd(&
   &              i-1, j, k-1, 3)+xd(i, j, k-1, 3)+xd(i-1, j-1, k, 3)+xd(i, &
   &              j-1, k, 3)+xd(i-1, j, k, 3)+xd(i, j, k, 3))
   xc(3) = eighth*(x(i-1, j-1, k-1, 3)+x(i, j-1, k-1, 3)+x(i-1&
   &              , j, k-1, 3)+x(i, j, k-1, 3)+x(i-1, j-1, k, 3)+x(i, j-1, k&
   &              , 3)+x(i-1, j, k, 3)+x(i, j, k, 3))
   ! Determine the coordinates relative to the
   ! center of rotation.
   xxcd(1) = xcd(1)
   xxc(1) = xc(1) - rotcenter(1)
   xxcd(2) = xcd(2)
   xxc(2) = xc(2) - rotcenter(2)
   xxcd(3) = xcd(3)
   xxc(3) = xc(3) - rotcenter(3)
   !print *,'xxc1',- rotRate(3)+ derivRotationMatrix(1,2),xxc
   ! Determine the rotation speed of the cell center,
   ! which is omega*r.
   scd(1) = rotrate(2)*xxcd(3) - rotrate(3)*xxcd(2)
   sc(1) = rotrate(2)*xxc(3) - rotrate(3)*xxc(2)
   scd(2) = rotrate(3)*xxcd(1) - rotrate(1)*xxcd(3)
   sc(2) = rotrate(3)*xxc(1) - rotrate(1)*xxc(3)
   scd(3) = rotrate(1)*xxcd(2) - rotrate(2)*xxcd(1)
   sc(3) = rotrate(1)*xxc(2) - rotrate(2)*xxc(1)
   !                   print *,'sc(1)',rotRate(2),xxc(3), -rotRate(3),xxc(2)
   ! Determine the coordinates relative to the
   ! rigid body rotation point.
   xxcd(1) = xcd(1)
   xxc(1) = xc(1) - rotationpoint(1)
   xxcd(2) = xcd(2)
   xxc(2) = xc(2) - rotationpoint(2)
   xxcd(3) = xcd(3)
   xxc(3) = xc(3) - rotationpoint(3)
   !print *,'xxc2',- rotRate(3)+ derivRotationMatrix(1,2),xxc
   ! Determine the total velocity of the cell center.
   ! This is a combination of rotation speed of this
   ! block and the entire rigid body rotation.
   !print *,'velgridx',velxGrid,rotRate(2)*xxc(3)+derivRotationMatrix(1,3)*xxc(3),- rotRate(3)+ derivRotationMatrix(1,2),xxc(2) 
   sd(i, j, k, 1) = scd(1) + derivrotationmatrix(1, 1)*xxcd(1) &
   &              + derivrotationmatrix(1, 2)*xxcd(2) + derivrotationmatrix(&
   &              1, 3)*xxcd(3)
   s(i, j, k, 1) = sc(1) + velxgrid + derivrotationmatrix(1, 1)&
   &              *xxc(1) + derivrotationmatrix(1, 2)*xxc(2) + &
   &              derivrotationmatrix(1, 3)*xxc(3)
   sd(i, j, k, 2) = scd(2) + derivrotationmatrix(2, 1)*xxcd(1) &
   &              + derivrotationmatrix(2, 2)*xxcd(2) + derivrotationmatrix(&
   &              2, 3)*xxcd(3)
   s(i, j, k, 2) = sc(2) + velygrid + derivrotationmatrix(2, 1)&
   &              *xxc(1) + derivrotationmatrix(2, 2)*xxc(2) + &
   &              derivrotationmatrix(2, 3)*xxc(3)
   sd(i, j, k, 3) = scd(3) + derivrotationmatrix(3, 1)*xxcd(1) &
   &              + derivrotationmatrix(3, 2)*xxcd(2) + derivrotationmatrix(&
   &              3, 3)*xxcd(3)
   s(i, j, k, 3) = sc(3) + velzgrid + derivrotationmatrix(3, 1)&
   &              *xxc(1) + derivrotationmatrix(3, 2)*xxc(2) + &
   &              derivrotationmatrix(3, 3)*xxc(3)
   END DO
   END DO
   END DO
   sfaceid = 0.0
   sfacejd = 0.0
   sfacekd = 0.0
   !print *,'s1',i,j,k,s(i,j,k,1)!,sc(1), &
   !                        derivRotationMatrix(1,1)*xxc(1) &
   !                        + derivRotationMatrix(1,2)*xxc(2) &
   !                        + derivRotationMatrix(1,3)*xxc(3)
   !                   print *,'rm1',derivRotationMatrix(1,3),xxc(3),&
   !                        derivRotationMatrix(1,2),xxc(2)
   !
   !            ************************************************************
   !            *                                                          *
   !            * Normal grid velocities of the faces.                     *
   !            *                                                          *
   !            ************************************************************
   !
   ! Loop over the three directions.
   loopdirection:DO mm=1,3
   ! Set the upper boundaries depending on the direction.
   SELECT CASE  (mm) 
   CASE (1_intType) 
   ! Normals in i-direction
   iie = ie
   jje = je
   kke = ke
   CASE (2_intType) 
   ! Normals in j-direction
   iie = je
   jje = ie
   kke = ke
   CASE (3_intType) 
   ! Normals in k-direction
   iie = ke
   jje = ie
   kke = je
   END SELECT
   !
   !              **********************************************************
   !              *                                                        *
   !              * Normal grid velocities in generalized i-direction.     *
   !              * mm == 1: i-direction                                   *
   !              * mm == 2: j-direction                                   *
   !              * mm == 3: k-direction                                   *
   !              *                                                        *
   !              **********************************************************
   !
   DO i=0,iie
   ! Set the pointers for the coordinates, normals and
   ! normal velocities for this generalized i-plane.
   ! This depends on the value of mm.
   SELECT CASE  (mm) 
   CASE (1_intType) 
   ! normals in i-direction
   xxd => xd(i, :, :, :)
   xx => x(i, :, :, :)
   ssd => sid(i, :, :, :)
   ss => si(i, :, :, :)
   sfaced => sfaceid(i, :, :)
   sface => sfacei(i, :, :)
   CASE (2_intType) 
   ! normals in j-direction
   xxd => xd(:, i, :, :)
   xx => x(:, i, :, :)
   ssd => sjd(:, i, :, :)
   ss => sj(:, i, :, :)
   sfaced => sfacejd(:, i, :)
   sface => sfacej(:, i, :)
   CASE (3_intType) 
   ! normals in k-direction
   xxd => xd(:, :, i, :)
   xx => x(:, :, i, :)
   ssd => skd(:, :, i, :)
   ss => sk(:, :, i, :)
   sfaced => sfacekd(:, :, i)
   sface => sfacek(:, :, i)
   END SELECT
   ! Loop over the k and j-direction of this generalized
   ! i-face. Note that due to the usage of the pointer
   ! xx an offset of +1 must be used in the coordinate
   ! array, because x originally starts at 0 for the
   ! i, j and k indices.
   DO k=1,kke
   DO j=1,jje
   ! Determine the coordinates of the face center,
   ! which are stored in xc.
   xcd(1) = fourth*(xxd(j+1, k+1, 1)+xxd(j, k+1, 1)+xxd(j+1, &
   &                k, 1)+xxd(j, k, 1))
   xc(1) = fourth*(xx(j+1, k+1, 1)+xx(j, k+1, 1)+xx(j+1, k, 1&
   &                )+xx(j, k, 1))
   xcd(2) = fourth*(xxd(j+1, k+1, 2)+xxd(j, k+1, 2)+xxd(j+1, &
   &                k, 2)+xxd(j, k, 2))
   xc(2) = fourth*(xx(j+1, k+1, 2)+xx(j, k+1, 2)+xx(j+1, k, 2&
   &                )+xx(j, k, 2))
   xcd(3) = fourth*(xxd(j+1, k+1, 3)+xxd(j, k+1, 3)+xxd(j+1, &
   &                k, 3)+xxd(j, k, 3))
   xc(3) = fourth*(xx(j+1, k+1, 3)+xx(j, k+1, 3)+xx(j+1, k, 3&
   &                )+xx(j, k, 3))
   ! Determine the coordinates relative to the
   ! center of rotation.
   xxcd(1) = xcd(1)
   xxc(1) = xc(1) - rotcenter(1)
   xxcd(2) = xcd(2)
   xxc(2) = xc(2) - rotcenter(2)
   xxcd(3) = xcd(3)
   xxc(3) = xc(3) - rotcenter(3)
   ! Determine the rotation speed of the face center,
   ! which is omega*r.
   scd(1) = rotrate(2)*xxcd(3) - rotrate(3)*xxcd(2)
   sc(1) = rotrate(2)*xxc(3) - rotrate(3)*xxc(2)
   scd(2) = rotrate(3)*xxcd(1) - rotrate(1)*xxcd(3)
   sc(2) = rotrate(3)*xxc(1) - rotrate(1)*xxc(3)
   scd(3) = rotrate(1)*xxcd(2) - rotrate(2)*xxcd(1)
   sc(3) = rotrate(1)*xxc(2) - rotrate(2)*xxc(1)
   ! Determine the coordinates relative to the
   ! rigid body rotation point.
   xxcd(1) = xcd(1)
   xxc(1) = xc(1) - rotationpoint(1)
   xxcd(2) = xcd(2)
   xxc(2) = xc(2) - rotationpoint(2)
   xxcd(3) = xcd(3)
   xxc(3) = xc(3) - rotationpoint(3)
   ! Determine the total velocity of the cell face.
   ! This is a combination of rotation speed of this
   ! block and the entire rigid body rotation.
   scd(1) = scd(1) + derivrotationmatrix(1, 1)*xxcd(1) + &
   &                derivrotationmatrix(1, 2)*xxcd(2) + derivrotationmatrix(&
   &                1, 3)*xxcd(3)
   sc(1) = sc(1) + velxgrid + derivrotationmatrix(1, 1)*xxc(1&
   &                ) + derivrotationmatrix(1, 2)*xxc(2) + &
   &                derivrotationmatrix(1, 3)*xxc(3)
   scd(2) = scd(2) + derivrotationmatrix(2, 1)*xxcd(1) + &
   &                derivrotationmatrix(2, 2)*xxcd(2) + derivrotationmatrix(&
   &                2, 3)*xxcd(3)
   sc(2) = sc(2) + velygrid + derivrotationmatrix(2, 1)*xxc(1&
   &                ) + derivrotationmatrix(2, 2)*xxc(2) + &
   &                derivrotationmatrix(2, 3)*xxc(3)
   scd(3) = scd(3) + derivrotationmatrix(3, 1)*xxcd(1) + &
   &                derivrotationmatrix(3, 2)*xxcd(2) + derivrotationmatrix(&
   &                3, 3)*xxcd(3)
   sc(3) = sc(3) + velzgrid + derivrotationmatrix(3, 1)*xxc(1&
   &                ) + derivrotationmatrix(3, 2)*xxc(2) + &
   &                derivrotationmatrix(3, 3)*xxc(3)
   ! Store the dot product of grid velocity sc and
   ! the normal ss in sFace.
   sfaced(j, k) = scd(1)*ss(j, k, 1) + sc(1)*ssd(j, k, 1) + &
   &                scd(2)*ss(j, k, 2) + sc(2)*ssd(j, k, 2) + scd(3)*ss(j, k&
   &                , 3) + sc(3)*ssd(j, k, 3)
   sface(j, k) = sc(1)*ss(j, k, 1) + sc(2)*ss(j, k, 2) + sc(3&
   &                )*ss(j, k, 3)
   END DO
   END DO
   END DO
   END DO loopdirection
   END IF
   ELSE
   sfaceid = 0.0
   sfacejd = 0.0
   sd = 0.0
   sfacekd = 0.0
   END IF
   END SUBROUTINE GRIDVELOCITIESFINELEVEL_BLOCK_D
