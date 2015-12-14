for BRANCH in master next; do
#for BRANCH in next; do
	for ARCH in default nix32 cross-win32 cross-win64; do
	#for ARCH in cross-win64 default;  do
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
			javac -cp lib/bridj-0.7.0.jar gen-$BRANCH-$JARCH/java/hu/keve/capstonebinding/*.java
		fi
	done
done
