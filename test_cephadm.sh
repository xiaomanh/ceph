#!/bin/bash -ex

SCRIPT_NAME=$(basename ${BASH_SOURCE[0]})

fsid='00000000-0000-0000-0000-0000deadbeef'
image='docker.io/ceph/daemon-base:latest-master-devel'
[ -z "$ip" ] && ip=127.0.0.1

OSD_IMAGE_NAME="${SCRIPT_NAME%.*}_osd.img"
OSD_IMAGE_SIZE='6G'
OSD_TO_CREATE=6
OSD_VG_NAME=${SCRIPT_NAME%.*}
OSD_LV_NAME=${SCRIPT_NAME%.*}

CEPHADM=../src/cephadm/cephadm

# add verbose logging
#CEPHADM_ARGS="$CEPHADM_ARGS -v"

# clean up previous run(s)?
$CEPHADM $CEPHADM_ARGS rm-cluster --fsid $fsid --force
vgchange -an $OSD_VG_NAME || true
loopdev=$(losetup -a | grep $(basename $OSD_IMAGE_NAME) | awk -F : '{print $1}')
if ! [ "$loopdev" = "" ]; then
    losetup -d $loopdev
fi
rm -f $OSD_IMAGE_NAME

cat <<EOF > c
[global]
	log to file = true
EOF

$CEPHADM $CEPHADM_ARGS \
    --image $image \
    bootstrap \
    --mon-id a \
    --mgr-id x \
    --fsid $fsid \
    --mon-ip $ip \
    --config c \
    --output-keyring k \
    --output-config c \
    --allow-overwrite \
    --skip-mon-network
chmod 644 k c

# mon.b
cp c c.mon
echo "public addrv = [v2:$ip:3301,v1:$ip:6790]" >> c.mon
$CEPHADM $CEPHADM_ARGS \
     --image $image \
     deploy --name mon.b \
     --fsid $fsid \
     --keyring /var/lib/ceph/$fsid/mon.a/keyring \
     --config c.mon
rm c.mon

# mgr.b
$CEPHADM $CEPHADM_ARGS shell --fsid $fsid --config c --keyring k -- \
    ceph auth get-or-create mgr.y \
        mon 'allow profile mgr' \
        osd 'allow *' \
        mds 'allow *' > k-mgr.y
$CEPHADM $CEPHADM_ARGS \
    --image $image \
    deploy --name mgr.y \
    --fsid $fsid \
    --keyring k-mgr.y \
    --config c

# mds.{k,j}
for id in k j; do
    $CEPHADM $CEPHADM_ARGS shell --fsid $fsid --config c --keyring k -- \
        ceph auth get-or-create mds.$id \
            mon 'allow profile mds' \
            mgr 'allow profile mds' \
            osd 'allow *' \
            mds 'allow *' > k-mds.$id
    $CEPHADM $CEPHADM_ARGS \
        --image $image \
        deploy --name mds.$id \
        --fsid $fsid \
        --keyring k-mds.$id \
        --config c
done

# add osd.{1,2,..}
dd if=/dev/zero of=$OSD_IMAGE_NAME bs=1 count=0 seek=$OSD_IMAGE_SIZE
loop_dev=$(losetup -f)
losetup $loop_dev $OSD_IMAGE_NAME
pvcreate $loop_dev && vgcreate $OSD_VG_NAME $loop_dev
for id in `seq 0 $((--OSD_TO_CREATE))`; do
    lvcreate -l $((100/$OSD_TO_CREATE))%VG -n $OSD_LV_NAME.$id $OSD_VG_NAME
    $SUDO $CEPHADM shell --fsid $fsid --config c --keyring k -- \
            ceph orch daemon add osd \
                $(hostname):/dev/$OSD_VG_NAME/$OSD_LV_NAME.$id
done

$CEPHADM $CEPHADM_ARGS shell --fsid $fsid --config c --keyring k -- ceph -s
