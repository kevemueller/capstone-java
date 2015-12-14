for BRANCH in master next; do
#for BRANCH in master; do
	for ARCH in default nix32 cross-win32 cross-win64; do
#	for ARCH in ;  do
		echo Processing $BRANCH / $ARCH
		case $ARCH in
		cross-win64)
			JARCH=win64
			;;
		cross-win32)
			JARCH=win32
			;;
		nix32)
			JARCH=linux_x86
			;;
		default)
			JARCH=linux_x64
			;;
		esac

		pushd capstone > /dev/null
			git checkout $BRANCH
			git clean -fx > /dev/null
			./make.sh $ARCH > ../make-$BRANCH-$ARCH.log 2> ../make-$BRANCH-$ARCH.err
			E=$?
		popd > /dev/null
		rm -rf gen-$BRANCH-$JARCH
		if [ $E -eq 0 ]; then 
			java -jar lib/jnaerator-0.12-shaded.jar @config.jnaerator @config-$BRANCH.jnaerator -arch $JARCH -o gen-$BRANCH-$JARCH/java @config-$JARCH.jnaerator
			for i in gen-$BRANCH-$JARCH/java/hu/keve/capstonebinding/*.java; do 
				sed -i  's/hu.keve.capstonebinding.cs_arm_op.Field1Union/Field1Union/' $i;
			done
		fi
	done

	# The generated Java files are assumed identical. Check it before merging.
	PKG=java/hu/keve/capstonebinding
	E=0
	diff -rq gen-$BRANCH-linux_x64/$PKG gen-$BRANCH-linux_x86/$PKG
	E=$[$E + $?]
	if [ -d gen-$BRANCH-win32 ]; then
		diff -rq gen-$BRANCH-linux_x64/$PKG gen-$BRANCH-win32/$PKG
		E=$[$E + $?]
	fi
	if [ -d gen-$BRANCH-win64 ]; then
		diff -rq gen-$BRANCH-linux_x64/$PKG gen-$BRANCH-win64/$PKG
		E=$[$E + $?]
	fi
	if [ $E -ne 0 ]; then
		echo generated java source for $BRANCH differs across architecture.
		echo this is unexpected
	else
		rm -rf gen-$BRANCH
		cp -a gen-$BRANCH-linux_x64 gen-$BRANCH
		for JARCH in linux_x86 win32 win64; do
			test -d gen-$BRANCH-$JARCH && cp -a gen-$BRANCH-$JARCH/java/lib/* gen-$BRANCH/java/lib/
		done
		mkdir gen-$BRANCH/bin
		cp -a gen-$BRANCH/java/lib/ gen-$BRANCH/bin/
		rm -rf gen-$BRANCH/java/lib/
		javac -cp lib/bridj-0.7.0.jar gen-$BRANCH/java/hu/keve/capstonebinding/*.java -d gen-$BRANCH/bin
		find gen-$BRANCH/java -name "*.java" -print0 | xargs -0 javadoc -classpath lib/bridj-0.7.0.jar -link http://nativelibs4java.sourceforge.net/bridj/api/0.7.0 -link http://download.oracle.com/javase/6/docs/api -d gen-$BRANCH/doc

	# TODO: add some license and other stuff
	# TODO: add an all-inclusive version for the lazy?
		
		jar cf capstonebinding-$BRANCH-bin.jar -C gen-$BRANCH/bin .
		jar cf capstonebinding-$BRANCH-src.jar -C gen-$BRANCH/java .
		jar cf capstonebinding-$BRANCH-javadoc.jar -C gen-$BRANCH/doc .
	fi
done
