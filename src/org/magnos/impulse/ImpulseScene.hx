/*
	Copyright (c) 2013 Randy Gaul http://RandyGaul.net

	This software is provided 'as-is', without any express or implied
	warranty. In no event will the authors be held liable for any damages
	arising from the use of this software.

	Permission is granted to anyone to use this software for any purpose,
	including commercial applications, and to alter it and redistribute it
	freely, subject to the following restrictions:
	  1. The origin of this software must not be misrepresented; you must not
		 claim that you wrote the original software. If you use this software
		 in a product, an acknowledgment in the product documentation would be
		 appreciated but is not required.
	  2. Altered source versions must be plainly marked as such, and must not be
		 misrepresented as being the original software.
	  3. This notice may not be removed or altered from any source distribution.

	Impulse Engine wrote by Randy Gaul https://www.randygaul.net
	Port to Java by Philip Diffenderfer http://magnos.org
	Port to Haxe and added pooling by Mansour Djawadi http://github.com/manjav
 */

package org.magnos.impulse;

class ImpulseScene {
	public var dt:Float = 0;
	public var iterations:Int;
	public var bodies:Array<Body> = new Array<Body>();
	public var contacts:Array<Manifold> = new Array<Manifold>();

	public function new(dt:Float, iterations:Int) {
		this.dt = dt;
		this.iterations = iterations;
	}

	public function step() {
		// Generate new collision info
		contacts = new Array();
		for (i in 0...bodies.length) {
			var A:Body = bodies[i];

			for (j in i + 1...bodies.length) {
				var B:Body = bodies[j];

				if (A.invMass == 0 && B.invMass == 0)
					continue;

				var m = man_in(A, B);
				m.solve();

				if (m.contactCount > 0)
					contacts.push(m);
			}
		}

		// Integrate forces
		for (i in 0...bodies.length)
			integrateForces(bodies[i], dt);

		// Initialize collision
		for (i in 0...contacts.length)
			contacts[i].initialize();

		// Solve collisions
		for (j in 0...iterations)
			for (i in 0...contacts.length)
				contacts[i].applyImpulse();

		// Integrate velocities
		for (i in 0...bodies.length)
			integrateVelocity(bodies[i], dt);

		// Correct positions
		for (i in 0...contacts.length)
		{
			contacts[i].positionalCorrection();
			man_ds(contacts[i]);
		}

		// Clear all forces
		for (i in 0...bodies.length) {
			var b:Body = bodies[i];
			b.force.set(0, 0);
			b.torque = 0;
		}
	}

	public function add(shape:Shape, x:Int, y:Int):Body {
		var b:Body = new Body(shape, x, y);
		bodies.push(b);
		return b;
	}
	
	public function remove(b:Body):Body {
		bodies.remove(b);
		return b;
	}

	public function clear() {
		contacts = new Array();
		bodies = new Array();
	}

	// Acceleration
	// F = mA
	// => A = F * 1/m
	// Explicit Euler
	// x += v * dt
	// v += (1/m * F) * dt
	// Semi-Implicit (Symplectic) Euler
	// v += (1/m * F) * dt
	// x += v * dt
	// see http://www.niksula.hut.fi/~hkankaan/Homepages/gravity.html
	public function integrateForces(b:Body, dt:Float) {
		//		if(b->im == 0.0f)
		//			return;
		//		b->velocity += (b->force * b->im + gravity) * (dt / 2.0f);
		//		b->angularVelocity += b->torque * b->iI * (dt / 2.0f);

		if (b.invMass == 0.0)
			return;

		var dts:Float = dt * 0.5;

		b.velocity.addsi(b.force, b.invMass * dts);
		b.velocity.addsi(ImpulseMath.GRAVITY, dts);
		b.angularVelocity += b.torque * b.invInertia * dts;
	}

	public function integrateVelocity(b:Body, dt:Float) {
		//		if(b->im == 0.0f)
		//			return;
		//		b->position += b->velocity * dt;
		//		b->orient += b->angularVelocity * dt;
		//		b->SetOrient( b->orient );
		//		IntegrateForces( b, dt );

		if (b.invMass == 0.0)
			return;

		b.position.addsi(b.velocity, dt);
		b.orient += b.angularVelocity * dt;
		b.setOrient(b.orient);

		integrateForces(b, dt);
	}

	var man_pool:Array<Manifold> = new Array();
	var man_i:Int = 0;
	public function man_ds(m:Manifold):Void
	{
		man_pool[man_i++] = m;
	}
	public function man_in(a:Body, b:Body):Manifold
	{
		if( man_i > 0 )
		{
			man_i--;
			man_pool[man_i].A = a;
			man_pool[man_i].B = b;
			return man_pool[man_i];
		}
		return new Manifold(a, b, this);
	}

	var vec_pool:Array<Vec2> = new Array<Vec2>();
	var vec_i:Int = 0;
	public function vec_ds(v:Vec2):Void
	{
		vec_pool[vec_i++] = v;
	}
	public function vec_in():Vec2
	{
		if( vec_i > 0 )
			return vec_pool[--vec_i].set(0,0);
		return new Vec2();
	}

	var mat_pool:Array<Mat2> = new Array();
	var mat_i:Int = 0;
	public function mat_ds(m:Mat2):Void
	{
		mat_pool[mat_i++] = m;
	}
	public function mat_in():Mat2
	{
		if( mat_i > 0 )
			return mat_pool[--mat_i].set(0,0,0,0);
		return new Mat2();
	}
}