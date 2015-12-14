#!/bin/bash

# this is a hack and shall be replaced by some nice maven stuff

BRANCHLIST="master next"
ARCHLIST="default nix32 cross-win32 cross-win64"
#BRANCHLIST="next"
#ARCHLIST=""

git pull --recurse-submodules
git submodule update --remote capstone
git submodule update --remote capstonej

for BRANCH in $BRANCHLIST; do
	pushd capstone
 		git checkout $BRANCH
		API_DATE=$(git show -s --format="%ci" | sed -n 's/\(....\)-\(..\)-\(..\).*/\1\2\3/p')
	popd 
	pushd capstonej && git checkout $BRANCH
	popd 
	API_MAJOR=$(sed -n 's/#define \+CS_API_MAJOR \+//p' $(find capstone -name capstone.h))
	API_MINOR=$(sed -n 's/#define \+CS_API_MINOR \+//p' $(find capstone -name capstone.h))
	for ARCH in $ARCHLIST;  do
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
			git clean -fx > /dev/null
			./make.sh $ARCH > ../make-$BRANCH-$ARCH.log 2> ../make-$BRANCH-$ARCH.err
			E=$?
		popd > /dev/null
		rm -rf gen/$BRANCH-$JARCH
		if [ $E -eq 0 ]; then 
			java -jar lib/jnaerator-0.12-shaded.jar @config.jnaerator @config-$BRANCH.jnaerator -arch $JARCH -o gen/$BRANCH-$JARCH/java @config-$JARCH.jnaerator
			for i in gen/$BRANCH-$JARCH/java/hu/keve/capstonebinding/*.java; do 
				sed -i  's/hu.keve.capstonebinding.cs_arm_op.Field1Union/Field1Union/' $i;
			done
		fi
	done

	# The generated Java files are assumed identical. Check it before merging.
	PKG=java/hu/keve/capstonebinding
	E=0
	if [ -d gen/$BRANCH-linux_x86 ]; then
		diff -rq gen/$BRANCH-linux_x64/$PKG gen/$BRANCH-linux_x86/$PKG
		E=$[$E + $?]
	fi
	if [ -d gen/$BRANCH-win32 ]; then
		diff -rq gen/$BRANCH-linux_x64/$PKG gen/$BRANCH-win32/$PKG
		E=$[$E + $?]
	fi
	if [ -d gen/$BRANCH-win64 ]; then
		diff -rq gen/$BRANCH-linux_x64/$PKG gen/$BRANCH-win64/$PKG
		E=$[$E + $?]
	fi
	if [ $E -ne 0 ]; then
		echo generated java source for $BRANCH differs across architecture.
		echo this is unexpected
	else
		rm -rf gen/$BRANCH
		cp -a gen/$BRANCH-linux_x64 gen/$BRANCH
		for JARCH in linux_x86 win32 win64; do
			test -d gen/$BRANCH-$JARCH && cp -a gen/$BRANCH-$JARCH/java/lib/* gen/$BRANCH/java/lib/
		done
		mkdir gen/$BRANCH/bin
		cp -a gen/$BRANCH/java/lib/ gen/$BRANCH/bin/
		rm -rf gen/$BRANCH/java/lib/
		javac -cp lib/bridj-0.7.0.jar gen/$BRANCH/java/hu/keve/capstonebinding/*.java -d gen/$BRANCH/bin
		find gen/$BRANCH/java -name "*.java" -print0 | xargs -0 javadoc -classpath lib/bridj-0.7.0.jar -link http://nativelibs4java.sourceforge.net/bridj/api/0.7.0 -link http://download.oracle.com/javase/6/docs/api -d gen/$BRANCH/doc > javadoc-capstonebinding-$BRANCH.log

	# TODO: add some license and other stuff
	# TODO: add an all-inclusive version for the lazy?

		CSBJARNAME=capstonebinding-${API_MAJOR}.${API_MINOR}_git${API_DATE}
		
		jar cf $CSBJARNAME-bin.jar -C gen/$BRANCH/bin .
		jar cf $CSBJARNAME-src.jar -C gen/$BRANCH/java .
		jar cf $CSBJARNAME-javadoc.jar -C gen/$BRANCH/doc .

		rm -rf build/csj
		mkdir -p build/csj/bin
		javac -cp lib/bridj-0.7.0.jar:$CSBJARNAME-bin.jar capstonej/capstonej/src/hu/keve/capstonej/*.java -d build/csj/bin
		find capstonej/capstonej -name "*.java" -print0 | xargs -0 javadoc -classpath lib/bridj-0.7.0.jar:$CSBJARNAME-bin.jar -link http://nativelibs4java.sourceforge.net/bridj/api/0.7.0 -link http://download.oracle.com/javase/6/docs/api -d build/csj/doc > javadoc-capstonej-$BRANCH.log
		CSJJARNAME=capstonej-${API_MAJOR}.${API_MINOR}_git

		jar cf $CSJJARNAME-bin.jar -C build/csj/bin .
		jar cf $CSJJARNAME-src.jar -C capstonej/capstonej/src .
		jar cf $CSJJARNAME-javadoc.jar -C build/csj/doc .
	fi
done
