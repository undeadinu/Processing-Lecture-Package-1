/**
 * Java implementation of the Navier-Stokes-Solver from
 * http://www.dgp.toronto.edu/people/stam/reality/Research/pdf/GDC03.pdf
 */
public class NavierStokesSolver {
	final static int N = 25;
	final static int SIZE = (N + 2) * (N + 2);
	double[] u = new double[SIZE];
	double[] v = new double[SIZE];
	double[] u_prev = new double[SIZE];
	double[] v_prev = new double[SIZE];
	double[] dense = new double[SIZE];
	double[] dense_prev = new double[SIZE];

	public NavierStokesSolver() {
	}

	public double getDx(int x, int y) {
		return u[INDEX(x+1, y+1)];
	}

	public double getDy(int x, int y) {
		return v[INDEX(x+1, y+1)];
	}

	public void applyForce(int cellX, int cellY, double vx, double vy) {
                cellX += 1;
                cellY += 1;
		double dx = u[INDEX(cellX, cellY)];
		double dy = v[INDEX(cellX, cellY)];

		u[INDEX(cellX, cellY)] = (vx != 0) ? PApplet.lerp((float) vx,
				(float) dx, 0.85f) : dx;
		v[INDEX(cellX, cellY)] = (vy != 0) ? PApplet.lerp((float) vy,
				(float) dy, 0.85f) : dy;

	}

	void tick(double dt, double visc, double diff) {
		vel_step(u, v, u_prev, v_prev, visc, dt);
		dens_step(dense, dense_prev, u, v, diff, dt);
	}

        // method used to be 'static' since this class is not a top level type
	final int INDEX(int i, int j) {
		return i + (N + 2) * j;
	}

	double[] tmp = new double[SIZE];
        // same applies to the swap operation ^^ 
	final void SWAP(double[] x0, double[] x) {
		System.arraycopy(x0, 0, tmp, 0, SIZE);
		System.arraycopy(x, 0, x0, 0, SIZE);
		System.arraycopy(tmp, 0, x, 0, SIZE);
	}

	void add_source(double[] x, double[] s, double dt) {
		int i, size = (N + 2) * (N + 2);
		for (i = 0; i < size; i++)
			x[i] += dt * s[i];
	}

	void diffuse(int b, double[] x, double[] x0, double diff, double dt) {
		int i, j, k;
		double a = dt * diff * N * N;
		for (k = 0; k < 20; k++) {
			for (i = 1; i <= N; i++) {
				for (j = 1; j <= N; j++) {
					x[INDEX(i, j)] = (x0[INDEX(i, j)] + a
							* (x[INDEX(i - 1, j)] + x[INDEX(i + 1, j)] + x[INDEX(i, j - 1)] + x[INDEX(
									i, j + 1)]))
							/ (1 + 4 * a);
				}
			}
			set_bnd(b, x);
		}
	}

	void advect(int b, double[] d, double[] d0, double[] u, double[] v, double dt) {
		int i, j, i0, j0, i1, j1;
		double x, y, s0, t0, s1, t1, dt0;
		dt0 = dt * N;
		for (i = 1; i <= N; i++) {
			for (j = 1; j <= N; j++) {
				x = i - dt0 * u[INDEX(i, j)];
				y = j - dt0 * v[INDEX(i, j)];
				if (x < 0.5)
					x = 0.5;
				if (x > N + 0.5)
					x = N + 0.5;
				i0 = (int) x;
				i1 = i0 + 1;
				if (y < 0.5)
					y = 0.5;
				if (y > N + 0.5)
					y = N + 0.5;
				j0 = (int) y;
				j1 = j0 + 1;
				s1 = x - i0;
				s0 = 1 - s1;
				t1 = y - j0;
				t0 = 1 - t1;
				d[INDEX(i, j)] = s0 * (t0 * d0[INDEX(i0, j0)] + t1 * d0[INDEX(i0, j1)])
						+ s1 * (t0 * d0[INDEX(i1, j0)] + t1 * d0[INDEX(i1, j1)]);
			}
		}
		set_bnd(b, d);
	}

	void set_bnd(int b, double[] x) {
		int i;
		for (i = 1; i <= N; i++) {
			x[INDEX(0, i)] = (b == 1) ? -x[INDEX(1, i)] : x[INDEX(1, i)];
			x[INDEX(N + 1, i)] = b == 1 ? -x[INDEX(N, i)] : x[INDEX(N, i)];
			x[INDEX(i, 0)] = b == 2 ? -x[INDEX(i, 1)] : x[INDEX(i, 1)];
			x[INDEX(i, N + 1)] = b == 2 ? -x[INDEX(i, N)] : x[INDEX(i, N)];
		}
		x[INDEX(0, 0)] = 0.5 * (x[INDEX(1, 0)] + x[INDEX(0, 1)]);
		x[INDEX(0, N + 1)] = 0.5 * (x[INDEX(1, N + 1)] + x[INDEX(0, N)]);
		x[INDEX(N + 1, 0)] = 0.5 * (x[INDEX(N, 0)] + x[INDEX(N + 1, 1)]);
		x[INDEX(N + 1, N + 1)] = 0.5 * (x[INDEX(N, N + 1)] + x[INDEX(N + 1, N)]);
	}

	void dens_step(double[] x, double[] x0, double[] u, double[] v, double diff,
			double dt) {
		add_source(x, x0, dt);
		SWAP(x0, x);
		diffuse(0, x, x0, diff, dt);
		SWAP(x0, x);
		advect(0, x, x0, u, v, dt);
	}

	void vel_step(double[] u, double[] v, double[] u0, double[] v0, double visc,
			double dt) {
		add_source(u, u0, dt);
		add_source(v, v0, dt);
		SWAP(u0, u);
		diffuse(1, u, u0, visc, dt);
		SWAP(v0, v);
		diffuse(2, v, v0, visc, dt);
		project(u, v, u0, v0);
		SWAP(u0, u);
		SWAP(v0, v);
		advect(1, u, u0, u0, v0, dt);
		advect(2, v, v0, u0, v0, dt);
		project(u, v, u0, v0);
	}

	void project(double[] u, double[] v, double[] p, double[] div) {
		int i, j, k;
		double h;
		h = 1.0 / N;
		for (i = 1; i <= N; i++) {
			for (j = 1; j <= N; j++) {
				div[INDEX(i, j)] = -0.5
						* h
						* (u[INDEX(i + 1, j)] - u[INDEX(i - 1, j)] + v[INDEX(i, j + 1)] - v[INDEX(
								i, j - 1)]);
				p[INDEX(i, j)] = 0;
			}
		}
		set_bnd(0, div);
		set_bnd(0, p);
		for (k = 0; k < 20; k++) {
			for (i = 1; i <= N; i++) {
				for (j = 1; j <= N; j++) {
					p[INDEX(i, j)] = (div[INDEX(i, j)] + p[INDEX(i - 1, j)]
							+ p[INDEX(i + 1, j)] + p[INDEX(i, j - 1)] + p[INDEX(i, j + 1)]) / 4;
				}
			}
			set_bnd(0, p);
		}
		for (i = 1; i <= N; i++) {
			for (j = 1; j <= N; j++) {
				u[INDEX(i, j)] -= 0.5 * (p[INDEX(i + 1, j)] - p[INDEX(i - 1, j)]) / h;
				v[INDEX(i, j)] -= 0.5 * (p[INDEX(i, j + 1)] - p[INDEX(i, j - 1)]) / h;
			}
		}
		set_bnd(1, u);
		set_bnd(2, v);
	}

}


//___________________________FLUID FUNCTIONS_________________________//
void updateFluid(){
  if(setFluid){
    handleMouseMotion();
    double dt = 1/frameRate;
    fluidSolver.tick(dt,visc,diff);
    paintMotionVector((float) vScale*2);
    
    vScale = velocityScale * 60/frameRate;
    paintParticles();
  }
}

void paintMotionVector(float scale) {
  int n = NavierStokesSolver.N;
  float cellHeight = boxSize / n;
  float cellWidth = boxSize / n;
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      float dx = (float) fluidSolver.getDx(i, j);
      float dy = (float) fluidSolver.getDy(i, j);

      float x = -boxSize/2 + cellWidth / 2 + cellWidth * i;
      float y = -boxSize/2 + cellHeight / 2 + cellHeight * j;
      dx *= scale;
      dy *= scale;
      stroke(100,150,255);
      strokeWeight(1);
      line(x, y,boxSize/2, x + dx, y + dy,boxSize/2);
    }
  }
}

void paintParticles() {
  int n = NavierStokesSolver.N;
  float cellHeight = boxSize / n;
  float cellWidth = boxSize / n;

  int c = color(255);
  for (int i = 0; i<physics.particles.size(); i++) {
    VerletParticle p = (VerletParticle)physics.particles.get(i);
    if (p != null) {
      int cellX = floor((boxSize/2+p.x) / cellWidth);
      int cellY = floor((boxSize/2+p.y)/ cellHeight);
      float dx = (float) fluidSolver.getDx(cellX, cellY);
      float dy = (float) fluidSolver.getDy(cellX, cellY);

      float lX = (boxSize/2+p.x) - cellX * cellWidth - cellWidth / 2;
      float lY = (boxSize/2+p.y) - cellY * cellHeight - cellHeight / 2;

      int v, h, vf, hf;

      if (lX > 0) {
	v = Math.min(n, cellX + 1);
	vf = 1;
      } else {
	v = Math.min(n, cellX - 1);
	vf = -1;
      }

      if (lY > 0) {
        h = Math.min(n, cellY + 1);
        hf = 1;
      } else {
        h = Math.min(n, cellY - 1);
        hf = -1;
      }

      float dxv = (float) fluidSolver.getDx(v, cellY);
      float dxh = (float) fluidSolver.getDx(cellX, h);
      float dxvh = (float) fluidSolver.getDx(v, h);

      float dyv = (float) fluidSolver.getDy(v, cellY);
      float dyh = (float) fluidSolver.getDy(cellX, h);
      float dyvh = (float) fluidSolver.getDy(v, h);

      dx = lerp(lerp(dx, dxv, hf * lY / cellWidth), lerp(dxh, dxvh, hf * lY / cellWidth), vf * lX / cellHeight);
      dy = lerp(lerp(dy, dyv, hf * lY / cellWidth), lerp(dyh, dyvh, hf * lY / cellWidth), vf * lX / cellHeight);
      
      double dblDx = dx*vScale;
      double dblDy = dy*vScale;
      float flDx = (float)dblDx;
      float flDy = (float)dblDy;
      
      double newPx = p.x+dblDx;
      double newPy = p.y+dblDy;
      
      //p.x += dx * vScale;
      //p.y += dy * vScale;
      
      if (p.x < -boxSize/2 || p.x > boxSize/2) {
        p.x = random(-boxSize/2,boxSize/2);
      }
      if (p.y < -boxSize/2 || p.y > boxSize/2) {
        p.y = random(-boxSize/2,boxSize/2);
      }
      
      
      p.addSelf(new Vec3D(flDx,flDy,0));
      //p.set((float)newPx,(float)newPy,0);
      //stroke(255);
      //point((int)p.x,(int)p.y,0);

    }
  }
}

void handleMouseMotion() {
  int mx;
  int my;
  if(fluidmode == 0){
        mx = int(map(mouseX,0,width,0,boxSize));
        my = int(map(mouseY,0,height,0,boxSize));
  }else{
    agent2D.selfWander2D();
    mx = int(boxSize/2+agent2D.pos.x);
    my = int(boxSize/2+agent2D.pos.y);
  }
        
    mx = max(1, mx);
    my = max(1, my);

    int n = NavierStokesSolver.N;
    float cellHeight = boxSize / n;
    float cellWidth = boxSize / n;

    double mouseDx = mx - oldMouseX;
    double mouseDy = my - oldMouseY;
    int cellX = floor(mx / cellWidth);
    int cellY = floor(my / cellHeight);

    mouseDx = (abs((float) mouseDx) > limitVelocity) ? Math.signum(mouseDx) * limitVelocity : mouseDx;
    mouseDy = (abs((float) mouseDy) > limitVelocity) ? Math.signum(mouseDy) * limitVelocity : mouseDy;

    fluidSolver.applyForce(cellX, cellY, mouseDx, mouseDy);

    oldMouseX = mx;
    oldMouseY = my;
}
